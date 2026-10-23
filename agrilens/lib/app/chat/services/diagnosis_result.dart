// Typed result types for the on-device leaf diagnosis service.

import '../models/prediction.dart';

/// Preprocessing contract from preprocess_contract.json
/// These values must match the training artifact exactly.
class PreprocessContract {
  static const int inputSize = 224;
  static const String colorOrder = 'RGB';
  static const double scale = 1.0 / 255.0;
  static const List<double> mean = [0.485, 0.456, 0.406];
  static const List<double> std = [0.229, 0.224, 0.225];
  static const String resizePolicy = 'direct_resize';

  // Version identifier stored alongside each prediction
  static const String version = 'v1_224_imagenet';
}

/// Model version stored alongside predictions for future compatibility
class ModelContract {
  static const String modelAssetPath = 'assets/models/agrilens_model.tflite';
  static const String version = 'v1_mobilenetv3';

  // Expected output tensors (confirmed from export notebook intent):
  // Output 0: logits [1, 9] float32
  // Output 1: embedding [1, 576] float32
  //
  // NOTE: Actual tensor indices must be verified against the live model.
  // This is confirmed by inspecting interpreter.getOutputTensors() at load time.
  static const int expectedNumClasses = 9;
  static const int expectedEmbeddingDim = 576;
}

/// Rejection thresholds from rejection_policy.json
class RejectionPolicy {
  /// Temperature used to scale logits before softmax
  static const double temperature = 1.0282130241394043;

  /// Minimum post-temperature softmax confidence to accept as possible_match
  static const double confidenceThreshold = 0.8;

  /// Minimum difference between top-1 and top-2 softmax probabilities
  static const double marginThreshold = 0.15;

  /// Minimum cosine similarity to stored class prototypes
  /// NOTE: Prototype similarity check is UNAVAILABLE until class-prototype
  /// artifacts are exported from training. This threshold is stored here
  /// but the check cannot run. See handoff notes.
  static const double prototypeSimilarityThreshold = 0.72;

  /// Whether prototype similarity check is available
  /// Set to true only when portable class-prototype artifacts are present
  /// in the training artifacts directory.
  static const bool prototypeCheckAvailable = false;
}

/// Ordered class map from class_map.json.
/// The order here is the EXACT training artifact order; do not sort or reorder.
class ClassMap {
  static const List<ClassEntry> entries = [
    ClassEntry(
      id: 0,
      crop: 'maize',
      condition: 'common_rust',
      label: 'maize__common_rust',
    ),
    ClassEntry(
      id: 1,
      crop: 'maize',
      condition: 'northern_leaf_blight',
      label: 'maize__northern_leaf_blight',
    ),
    ClassEntry(
      id: 2,
      crop: 'maize',
      condition: 'gray_leaf_spot',
      label: 'maize__gray_leaf_spot',
    ),
    ClassEntry(
      id: 3,
      crop: 'maize',
      condition: 'healthy',
      label: 'maize__healthy',
    ),
    ClassEntry(
      id: 4,
      crop: 'tomato',
      condition: 'bacterial_spot',
      label: 'tomato__bacterial_spot',
    ),
    ClassEntry(
      id: 5,
      crop: 'tomato',
      condition: 'early_blight',
      label: 'tomato__early_blight',
    ),
    ClassEntry(
      id: 6,
      crop: 'tomato',
      condition: 'late_blight',
      label: 'tomato__late_blight',
    ),
    ClassEntry(
      id: 7,
      crop: 'tomato',
      condition: 'leaf_mold',
      label: 'tomato__leaf_mold',
    ),
    ClassEntry(
      id: 8,
      crop: 'tomato',
      condition: 'healthy',
      label: 'tomato__healthy',
    ),
  ];

  /// Look up a class entry by its integer ID.
  /// Returns null for out-of-range IDs.
  static ClassEntry? byId(int id) {
    if (id < 0 || id >= entries.length) return null;
    return entries[id];
  }
}

/// A single entry in the class map.
class ClassEntry {
  final int id;
  final String crop;
  final String condition;
  final String label;

  const ClassEntry({
    required this.id,
    required this.crop,
    required this.condition,
    required this.label,
  });
}

/// Raw output from running the TFLite interpreter.
/// Kept separate from the typed [DiagnosisResult] to allow inspection.
class RawInferenceOutput {
  /// Raw logits before temperature scaling; length must be [ModelContract.expectedNumClasses]
  final List<double> logits;

  /// Embedding vector; length must be [ModelContract.expectedEmbeddingDim].
  /// Nullable until tensor layout is confirmed on the actual model file.
  final List<double>? embedding;

  /// Index of the actual logits output tensor (confirmed at load time)
  final int logitsTensorIndex;

  /// Index of the embedding output tensor (confirmed at load time), or null
  /// if the model has only one output or embedding is not present
  final int? embeddingTensorIndex;

  const RawInferenceOutput({
    required this.logits,
    this.embedding,
    required this.logitsTensorIndex,
    this.embeddingTensorIndex,
  });
}

/// The final typed result returned from [DiagnosisService].
sealed class DiagnosisResult {
  const DiagnosisResult();
}

/// Classifier returned a result with acceptable confidence and margin.
class DiagnosisMatch extends DiagnosisResult {
  final ClassEntry classEntry;
  final DecisionState decisionState;
  final double topLogit;
  final double calibratedScore;
  final double margin;

  /// Null until prototype artifacts are exported.
  final double? prototypeSimilarity;

  const DiagnosisMatch({
    required this.classEntry,
    required this.decisionState,
    required this.topLogit,
    required this.calibratedScore,
    required this.margin,
    this.prototypeSimilarity,
  });
}

/// Classifier produced a result, but confidence or margin is below threshold.
class DiagnosisUncertain extends DiagnosisResult {
  final ClassEntry topClass;
  final double calibratedScore;
  final double margin;
  final String reason;

  const DiagnosisUncertain({
    required this.topClass,
    required this.calibratedScore,
    required this.margin,
    required this.reason,
  });
}

/// Image could not be classified: decode failure, inference error, or model
/// output indicates the image is not a supported leaf.
class DiagnosisFailure extends DiagnosisResult {
  final DiagnosisFailureKind kind;
  final String message;

  const DiagnosisFailure({required this.kind, required this.message});
}

enum DiagnosisFailureKind {
  /// Could not decode the image file (corrupt, unsupported format, orientation)
  imageDecodeFailed,

  /// Model loaded but inference threw an exception
  inferenceFailed,

  /// Model file could not be loaded from assets
  modelLoadFailed,

  /// Output tensor shape or count does not match expected contract
  outputLayoutMismatch,

  /// All logit values are the same or extremely close (uniform distribution),
  /// suggesting the image is not a leaf at all.
  uniformOutput,
}
