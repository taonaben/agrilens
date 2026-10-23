// Local conversational model service.
// Wraps the bundled Qwen3-0.6B-Q8_0.gguf model via llamadart 0.1.0.
//
// Provides a controlled interface that accepts a prediction context and
// prior messages, never raw image data or unrestricted prompting.
//
// IMPORTANT: Loading a 0.6B Q8 model (~700 MB) takes several seconds on
// a mid-range phone. Load once at app start and reuse. Generation may
// take 5–30 seconds depending on device and context length.
//
// Owner decision required: whether this local model quality is acceptable
// for the release, or whether a hosted model should be used instead.
// This service is the integration point for that comparison.

import 'package:llamadart/llamadart.dart';
// ignore: implementation_imports
import 'package:llamadart/src/llama_service_native.dart' as llama_native;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'dart:io';

import 'diagnosis_result.dart';
import 'service_interfaces.dart';

/// State of the conversational model service.
enum LlmServiceState { unloaded, loading, ready, generating, error, disposed }

/// A single generated token chunk during streaming.
class LlmChunk {
  final String text;
  const LlmChunk(this.text);
}

/// Result of a generation call.
sealed class LlmResult {
  const LlmResult();
}

/// Generation completed successfully.
class LlmSuccess extends LlmResult {
  final String text;
  const LlmSuccess(this.text);
}

/// Generation was cancelled by the caller.
class LlmCancelled extends LlmResult {
  const LlmCancelled();
}

/// Generation failed with an error.
class LlmError extends LlmResult {
  final String message;
  const LlmError(this.message);
}

/// Configuration for the LLM service.
class LlmServiceConfig {
  /// Asset path of the GGUF model file
  static const String modelAssetPath = 'assets/models/Qwen3-0.6B-Q8_0.gguf';

  /// Maximum tokens to generate per response
  /// Kept small to limit latency and memory pressure on device
  static const int maxResponseTokens = 256;

  /// Context window size
  /// Kept conservative to fit low-memory devices
  static const int contextSize = 2048;

  /// Temperature: low value for more focused, less creative responses
  static const double temperature = 0.4;

  /// System prompt that bounds the model to its role.
  /// The model MUST NOT diagnose images, prescribe chemicals, or invent
  /// guidance beyond what the classifier result and reviewed facts provide.
  static const String systemPrompt =
      '''You are a helpful assistant in the AgriLens plant diagnosis app.
Your role is to explain the classifier result clearly and honestly.

Rules you must follow:
- Only discuss the classifier result that was provided to you.
- Do not diagnose images yourself or override the classifier.
- Do not prescribe pesticides, chemicals, or specific doses.
- Do not fabricate treatment advice that hasn't been reviewed.
- Acknowledge uncertainty clearly when the result is uncertain.
- Keep your response concise (2-4 sentences).
- If the result says "uncertain" or "unsupported", say so honestly and suggest the farmer consult a local expert or try a clearer photo.

Reminder: A "healthy" result means no supported condition was recognized in this photo, not that the plant is definitely healthy.''';
}

/// Service that provides conversational responses about classifier results.
///
/// The model explains the classifier output within safe boundaries.
/// It does not diagnose images or generate unreviewed treatment advice.
///
/// Lifecycle:
///   1. Call [load] once to copy the GGUF asset and initialize the runtime.
///   2. Call [generateResponse] with classifier context.
///   3. Call [cancel] to stop an in-progress generation.
///   4. Call [dispose] when done.
class LocalLlmService implements LlmServiceInterface {
  LlamaServiceBase? _service;
  LlmServiceState _state = LlmServiceState.unloaded;

  // Track whether a generation is in progress so cancel() is meaningful
  bool _generationActive = false;

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Current state of the service.
  LlmServiceState get state => _state;

  /// Whether the service is ready to generate.
  @override
  bool get isReady => _state == LlmServiceState.ready;

  /// Load the bundled GGUF model.
  ///
  /// This copies the asset to a writable location on first run
  /// (llamadart requires a file path, not a Flutter asset stream).
  /// Subsequent loads reuse the cached copy.
  ///
  /// Returns normally on success. Sets [state] to [LlmServiceState.error]
  /// and records [lastError] on failure; does not throw.
  String? lastError;

  @override
  Future<void> load() async {
    if (_state == LlmServiceState.ready) return;
    if (_state == LlmServiceState.disposed) {
      lastError = 'Service has been disposed.';
      _state = LlmServiceState.error;
      return;
    }

    _state = LlmServiceState.loading;

    try {
      // llamadart 0.1.0 requires a file path, not a Flutter asset path.
      // Copy the asset to the app's documents directory if not already there.
      final modelPath = await _ensureModelFile();
      if (modelPath == null) {
        lastError = 'Could not copy model asset to app storage.';
        _state = LlmServiceState.error;
        return;
      }

      final service = llama_native.LlamaService();
      await service.init(
        modelPath,
        modelParams: ModelParams(
          contextSize: LlmServiceConfig.contextSize,
          gpuLayers: 0, // CPU-only for first integration; profiling needed
          preferredBackend: GpuBackend.cpu,
        ),
      );

      _service = service;
      _state = LlmServiceState.ready;
      lastError = null;
    } catch (e) {
      lastError = 'Model load failed: $e';
      _state = LlmServiceState.error;
    }
  }

  /// Generate a response explaining [diagnosisResult] to the user.
  ///
  /// [priorMessages] is the recent conversation history (user+assistant turns)
  /// used to maintain context for follow-up questions.
  ///
  /// [onChunk] is called for each streamed token as it arrives.
  ///
  /// Returns a [LlmResult] describing the final outcome.
  @override
  Future<LlmResult> generateResponse({
    required DiagnosisResult diagnosisResult,
    List<Map<String, String>> priorMessages = const [],
    String? userFollowUp,
    void Function(LlmChunk)? onChunk,
  }) async {
    if (_state != LlmServiceState.ready || _service == null) {
      return LlmError(
        'Service is not ready (state: $_state). Load the model first.',
      );
    }

    _state = LlmServiceState.generating;
    _generationActive = true;

    try {
      // Build the prompt from the diagnosis context
      final messages = _buildMessages(
        diagnosisResult: diagnosisResult,
        priorMessages: priorMessages,
        userFollowUp: userFollowUp,
      );

      // Apply the model's chat template
      final prompt = await _service!.applyChatTemplate(
        messages,
        addAssistant: true,
      );

      final params = GenerationParams(
        maxTokens: LlmServiceConfig.maxResponseTokens,
        temp: LlmServiceConfig.temperature,
        stopSequences: ['<|im_end|>', '</s>', '<|endoftext|>'],
      );

      // Stream tokens and collect the result
      final buffer = StringBuffer();
      await for (final chunk in _service!.generate(prompt, params: params)) {
        if (!_generationActive) break;
        buffer.write(chunk);
        onChunk?.call(LlmChunk(chunk));
      }

      _generationActive = false;
      _state = LlmServiceState.ready;

      final text = buffer.toString().trim();
      if (text.isEmpty) {
        return const LlmError('Model produced an empty response.');
      }
      return LlmSuccess(text);
    } catch (e) {
      _generationActive = false;
      _state = LlmServiceState.ready;
      return LlmError('Generation error: $e');
    }
  }

  /// Cancel an in-progress generation.
  @override
  void cancel() {
    if (_generationActive && _service != null) {
      _service!.cancelGeneration();
      _generationActive = false;
    }
  }

  /// Dispose the service and release native resources.
  @override
  void dispose() {
    cancel();
    _service?.dispose();
    _service = null;
    _state = LlmServiceState.disposed;
  }

  // ── Internal: prompt construction ───────────────────────────────────────────

  /// Build the message list for applyChatTemplate.
  ///
  /// The system prompt bounds the model.
  /// The assistant receives the classifier result as its first user turn.
  /// Prior conversation history is appended.
  /// An optional follow-up question is added as the final user turn.
  List<LlamaChatMessage> _buildMessages({
    required DiagnosisResult diagnosisResult,
    required List<Map<String, String>> priorMessages,
    String? userFollowUp,
  }) {
    final messages = <LlamaChatMessage>[
      const LlamaChatMessage(
        role: 'system',
        content: LlmServiceConfig.systemPrompt,
      ),
    ];

    // First user turn: present the classifier result as a factual briefing
    final resultSummary = _summariseDiagnosisResult(diagnosisResult);
    messages.add(LlamaChatMessage(role: 'user', content: resultSummary));

    // Append prior turns (up to a bounded context window)
    // Limit to last 4 turns to keep context size manageable
    final bounded =
        priorMessages.length > 4
            ? priorMessages.sublist(priorMessages.length - 4)
            : priorMessages;

    for (final msg in bounded) {
      final role = msg['role'] ?? 'user';
      final content = msg['content'] ?? '';
      if (content.isNotEmpty) {
        messages.add(LlamaChatMessage(role: role, content: content));
      }
    }

    // Optional follow-up question from the farmer
    if (userFollowUp != null && userFollowUp.trim().isNotEmpty) {
      messages.add(
        LlamaChatMessage(role: 'user', content: userFollowUp.trim()),
      );
    }

    return messages;
  }

  /// Render a [DiagnosisResult] as a factual summary for the LLM.
  ///
  /// This is the only information the model receives about the image.
  /// It must not imply the model has seen the image or can diagnose it.
  String _summariseDiagnosisResult(DiagnosisResult result) {
    return switch (result) {
      DiagnosisMatch(
        :final classEntry,
        :final calibratedScore,
        :final decisionState,
      ) =>
        'The on-device classifier analysed the leaf photo and returned the '
            'following result:\n'
            '- Crop: ${classEntry.crop}\n'
            '- Possible condition: ${classEntry.condition.replaceAll('_', ' ')}\n'
            '- Confidence: ${(calibratedScore * 100).toStringAsFixed(1)}%\n'
            '- Decision: $decisionState\n\n'
            'Note: "${classEntry.condition == 'healthy' ? 'No supported condition was recognised' : 'This is a possible match, not a confirmed diagnosis'}." '
            'Please explain this result clearly and helpfully to the farmer.',

      DiagnosisUncertain(
        :final topClass,
        :final calibratedScore,
        :final reason,
      ) =>
        'The on-device classifier ran but the result is uncertain:\n'
            '- Top candidate: ${topClass.crop} / ${topClass.condition.replaceAll('_', ' ')}\n'
            '- Confidence: ${(calibratedScore * 100).toStringAsFixed(1)}% (below threshold)\n'
            '- Reason: $reason\n\n'
            'Please tell the farmer the result is uncertain and suggest a clearer '
            'photo or local expert consultation.',

      DiagnosisFailure(:final kind, :final message) =>
        'The classifier could not complete the analysis:\n'
            '- Error type: $kind\n'
            '- Details: $message\n\n'
            'Please tell the farmer the analysis did not complete and suggest '
            'they try again with a clearer, well-lit leaf photo.',
    };
  }

  // ── Internal: model file management ─────────────────────────────────────────

  /// Copy the GGUF model asset to app-writable storage if needed.
  ///
  /// Returns the file path, or null on failure.
  ///
  /// The GGUF file is ~650 MB; copying only happens once and is idempotent.
  Future<String?> _ensureModelFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dest = File('${dir.path}/agrilens_llm.gguf');

      if (await dest.exists()) {
        return dest.path;
      }

      // Copy from Flutter asset bundle to the filesystem
      final assetData = await rootBundle.load(LlmServiceConfig.modelAssetPath);
      await dest.writeAsBytes(assetData.buffer.asUint8List(), flush: true);

      return dest.path;
    } catch (_) {
      return null;
    }
  }
}
