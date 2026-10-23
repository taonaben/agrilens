// On-device leaf diagnosis service.
// Loads the bundled TFLite model, preprocesses an image, runs inference,
// applies calibrated rejection, and returns a typed DiagnosisResult.
//
// IMPORTANT: This service runs on the device (Android/iOS only).
// Wrap calls in compute() or use IsolateInterpreter for heavy workloads
// to avoid blocking the UI thread.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'diagnosis_result.dart';
import 'service_interfaces.dart';
import '../models/prediction.dart' show DecisionState;

/// Service that wraps the bundled TFLite leaf-diagnosis model.
///
/// Lifecycle:
///   1. Call [load] once. This verifies tensor layout against the contract.
///   2. Call [diagnose] with a local image file path or asset path.
///   3. Call [dispose] when the service is no longer needed.
class DiagnosisService implements DiagnosisServiceInterface {
  Interpreter? _interpreter;
  bool _isLoaded = false;

  // Verified tensor indices – assigned after [_verifyOutputLayout]
  int _logitsTensorIndex = -1;
  int? _embeddingTensorIndex;

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Whether the model is loaded and ready for inference.
  @override
  bool get isLoaded => _isLoaded;

  /// Load the bundled TFLite model and verify its output layout.
  ///
  /// Throws [DiagnosisFailure] on load or layout mismatch.
  /// Call once at app start; keep the instance alive.
  @override
  Future<void> load() async {
    if (_isLoaded) return;

    try {
      _interpreter = await Interpreter.fromAsset(
        ModelContract.modelAssetPath,
        options: InterpreterOptions()..threads = 2,
      );
    } catch (e) {
      throw DiagnosisFailure(
        kind: DiagnosisFailureKind.modelLoadFailed,
        message: 'Could not load TFLite model: $e',
      );
    }

    final layoutError = _verifyOutputLayout();
    if (layoutError != null) {
      _interpreter?.close();
      _interpreter = null;
      throw layoutError;
    }

    _isLoaded = true;
  }

  /// Run on-device diagnosis for [imagePath] (filesystem path or asset path).
  ///
  /// Returns one of:
  /// - [DiagnosisMatch] – classifier found a class above thresholds
  /// - [DiagnosisUncertain] – classifier ran but evidence is weak
  /// - [DiagnosisFailure] – decode or inference error (recoverable)
  @override
  Future<DiagnosisResult> diagnose(String imagePath) async {
    if (!_isLoaded || _interpreter == null) {
      return const DiagnosisFailure(
        kind: DiagnosisFailureKind.modelLoadFailed,
        message: 'Model is not loaded. Call load() first.',
      );
    }

    // 1. Decode and preprocess image
    final Float32List? inputTensor = await _preprocessImage(imagePath);
    if (inputTensor == null) {
      return const DiagnosisFailure(
        kind: DiagnosisFailureKind.imageDecodeFailed,
        message: 'Could not decode the image. Check the file and try again.',
      );
    }

    // 2. Run inference
    final RawInferenceOutput? raw = _runInference(inputTensor);
    if (raw == null) {
      return const DiagnosisFailure(
        kind: DiagnosisFailureKind.inferenceFailed,
        message: 'Inference failed unexpectedly. Try again.',
      );
    }

    // 3. Apply rejection policy and return typed result
    return _applyRejectionPolicy(raw);
  }

  /// Release interpreter resources.
  @override
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }

  // ── Internal: output layout verification ────────────────────────────────────

  /// Verify output tensors match the expected contract.
  /// Returns null on success, or a [DiagnosisFailure] on mismatch.
  ///
  /// The export notebook intends:
  ///   Output 0: logits  [1, 9]   float32
  ///   Output 1: embedding [1, 576] float32
  ///
  /// Tensors are identified by shape, not assumed index (per plan requirement).
  DiagnosisFailure? _verifyOutputLayout() {
    final interpreter = _interpreter!;
    final outputCount = interpreter.getOutputTensors().length;

    if (outputCount < 1) {
      return const DiagnosisFailure(
        kind: DiagnosisFailureKind.outputLayoutMismatch,
        message: 'Model has no output tensors.',
      );
    }

    // Scan all outputs for the logits tensor [1, 9] and embedding [1, 576]
    int? logitsIdx;
    int? embeddingIdx;

    for (int i = 0; i < outputCount; i++) {
      final shape = interpreter.getOutputTensor(i).shape;
      if (shape.length == 2 && shape[0] == 1) {
        if (shape[1] == ModelContract.expectedNumClasses) {
          logitsIdx = i;
        } else if (shape[1] == ModelContract.expectedEmbeddingDim) {
          embeddingIdx = i;
        }
      }
    }

    if (logitsIdx == null) {
      // Fallback: if output 0's total elements equal the class count, use it
      final out0 = interpreter.getOutputTensor(0);
      final totalElements = out0.shape.fold(1, (a, b) => a * b);
      if (totalElements == ModelContract.expectedNumClasses) {
        logitsIdx = 0;
        // Non-standard layout; the plan requires logging this case in production
      } else {
        final shapes = List.generate(
          outputCount,
          (i) => interpreter.getOutputTensor(i).shape,
        );
        return DiagnosisFailure(
          kind: DiagnosisFailureKind.outputLayoutMismatch,
          message:
              'Could not find logits tensor of shape '
              '[1, ${ModelContract.expectedNumClasses}]. '
              'Found $outputCount output(s) with shapes: $shapes',
        );
      }
    }

    _logitsTensorIndex = logitsIdx;
    _embeddingTensorIndex = embeddingIdx;
    return null;
  }

  // ── Internal: preprocessing ─────────────────────────────────────────────────

  /// Load and preprocess an image into a model-ready Float32List tensor.
  ///
  /// Contract from preprocess_contract.json:
  ///   - Resize to 224×224 directly (no padding/crop)
  ///   - Channel order: RGB
  ///   - Scale: uint8 / 255.0
  ///   - Normalize: (value - mean) / std  (ImageNet stats)
  ///   - Output layout: [1, 224, 224, 3] float32, channel-last (NHWC)
  ///
  /// Returns null if the file cannot be decoded.
  Future<Float32List?> _preprocessImage(String imagePath) async {
    try {
      // Load bytes – try as Flutter asset, then as a filesystem file
      Uint8List rawBytes;
      try {
        final bd = await rootBundle.load(imagePath);
        rawBytes = bd.buffer.asUint8List();
      } catch (_) {
        final file = File(imagePath);
        if (!await file.exists()) return null;
        rawBytes = await file.readAsBytes();
      }

      // Decode and resize to 224×224 RGBA
      final codec = await ui.instantiateImageCodec(
        rawBytes,
        targetWidth: PreprocessContract.inputSize,
        targetHeight: PreprocessContract.inputSize,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      image.dispose();

      if (byteData == null) return null;

      final pixelBytes = byteData.buffer.asUint8List();
      final int w = PreprocessContract.inputSize;
      final int h = PreprocessContract.inputSize;

      // Build [1, H, W, 3] float32 tensor with ImageNet normalization
      final tensor = Float32List(h * w * 3);
      int idx = 0;

      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final int p = (y * w + x) * 4; // RGBA pixel offset
          // R, G, B channels – A channel is ignored
          tensor[idx++] =
              (pixelBytes[p] / 255.0 - PreprocessContract.mean[0]) /
              PreprocessContract.std[0];
          tensor[idx++] =
              (pixelBytes[p + 1] / 255.0 - PreprocessContract.mean[1]) /
              PreprocessContract.std[1];
          tensor[idx++] =
              (pixelBytes[p + 2] / 255.0 - PreprocessContract.mean[2]) /
              PreprocessContract.std[2];
        }
      }

      return tensor;
    } catch (_) {
      return null;
    }
  }

  // ── Internal: inference ──────────────────────────────────────────────────────

  /// Run the interpreter and return raw tensor outputs.
  RawInferenceOutput? _runInference(Float32List inputFlat) {
    final interpreter = _interpreter!;
    try {
      final int h = PreprocessContract.inputSize;
      final int w = PreprocessContract.inputSize;
      final input = inputFlat.reshape([1, h, w, 3]);

      // Prepare output buffers
      final logitsFlat = List<double>.filled(
        ModelContract.expectedNumClasses,
        0.0,
      );
      final Map<int, Object> outputs = {
        _logitsTensorIndex: logitsFlat.reshape([
          1,
          ModelContract.expectedNumClasses,
        ]),
      };

      List<double>? embeddingFlat;
      if (_embeddingTensorIndex != null) {
        embeddingFlat = List<double>.filled(
          ModelContract.expectedEmbeddingDim,
          0.0,
        );
        outputs[_embeddingTensorIndex!] = embeddingFlat.reshape([
          1,
          ModelContract.expectedEmbeddingDim,
        ]);
      }

      interpreter.runForMultipleInputs([input], outputs);

      return RawInferenceOutput(
        logits: logitsFlat,
        embedding: embeddingFlat,
        logitsTensorIndex: _logitsTensorIndex,
        embeddingTensorIndex: _embeddingTensorIndex,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Internal: rejection policy ───────────────────────────────────────────────

  /// Apply the rejection policy and return a typed [DiagnosisResult].
  ///
  /// Steps from rejection_policy.json:
  ///   1. Uniform check (sanity)
  ///   2. Temperature-scale the logits
  ///   3. Softmax
  ///   4. Check top-1 confidence >= 0.8
  ///   5. Check margin (top-1 − top-2) >= 0.15
  ///   6. Prototype similarity check – UNAVAILABLE (no prototype artifact)
  ///
  /// NOTE on prototype check: the policy requires cosine similarity ≥ 0.72
  /// to class prototypes. The portable prototype artifact is not yet exported
  /// from training. This check is recorded here but not applied. See handoff.
  DiagnosisResult _applyRejectionPolicy(RawInferenceOutput raw) {
    final logits = raw.logits;

    // Sanity: uniform logits indicate garbage input (not a leaf)
    final double minLogit = logits.reduce(math.min);
    final double maxLogit = logits.reduce(math.max);
    if ((maxLogit - minLogit).abs() < 1e-5) {
      return const DiagnosisFailure(
        kind: DiagnosisFailureKind.uniformOutput,
        message:
            'The image does not appear to be a leaf. Please try a clear, '
            'well-lit photo of a single leaf.',
      );
    }

    // Temperature scaling + softmax
    final scaledLogits = logits
        .map((l) => l / RejectionPolicy.temperature)
        .toList(growable: false);
    final probs = _softmax(scaledLogits);

    // Find top-1 and top-2 indices and probabilities
    int top1Idx = 0;
    int top2Idx = -1;
    double top1 = probs[0];
    double top2 = -1.0;

    for (int i = 1; i < probs.length; i++) {
      if (probs[i] > top1) {
        top2 = top1;
        top2Idx = top1Idx;
        top1 = probs[i];
        top1Idx = i;
      } else if (probs[i] > top2) {
        top2 = probs[i];
        top2Idx = i;
      }
    }

    final double margin = top2Idx >= 0 ? top1 - top2 : top1;
    final double calibratedScore = top1;
    final double topLogit = logits[top1Idx];

    final ClassEntry? classEntry = ClassMap.byId(top1Idx);
    if (classEntry == null) {
      return DiagnosisFailure(
        kind: DiagnosisFailureKind.outputLayoutMismatch,
        message: 'Top class index $top1Idx is out of range.',
      );
    }

    // Confidence threshold check
    if (calibratedScore < RejectionPolicy.confidenceThreshold) {
      return DiagnosisUncertain(
        topClass: classEntry,
        calibratedScore: calibratedScore,
        margin: margin,
        reason:
            'Confidence ${(calibratedScore * 100).toStringAsFixed(1)}% is below '
            'the ${(RejectionPolicy.confidenceThreshold * 100).round()}% threshold. '
            'Please try a clearer photo of the leaf.',
      );
    }

    // Margin threshold check
    if (margin < RejectionPolicy.marginThreshold) {
      return DiagnosisUncertain(
        topClass: classEntry,
        calibratedScore: calibratedScore,
        margin: margin,
        reason:
            'The result is ambiguous – the image resembles multiple conditions. '
            'Try a more focused photo or seek local expert guidance.',
      );
    }

    // All available checks passed
    return DiagnosisMatch(
      classEntry: classEntry,
      decisionState: DecisionState.possibleMatch,
      topLogit: topLogit,
      calibratedScore: calibratedScore,
      margin: margin,
      prototypeSimilarity: null, // Unavailable until prototypes are exported
    );
  }

  // ── Math ─────────────────────────────────────────────────────────────────────

  static List<double> _softmax(List<double> logits) {
    final double maxLogit = logits.reduce(math.max);
    final exps = logits.map((l) => math.exp(l - maxLogit)).toList();
    final double sum = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sum).toList();
  }
}
