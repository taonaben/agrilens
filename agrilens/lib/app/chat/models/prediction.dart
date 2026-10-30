// Domain model for a prediction result.
// Stores classifier output, decision state, and model metadata.

enum DecisionState { possibleMatch, uncertain, unsupportedOrUnclear }

class Prediction {
  final String id;
  final String messageId;
  final int classId; // Ordered ID from the model version's class map
  final String crop; // "maize" or "tomato"
  final String condition; // e.g., "common_rust", "healthy"
  final DecisionState decisionState;
  final double topLogit;
  final double calibratedScore;
  final double margin;
  final double? prototypeSimilarity; // nullable until prototypes available
  final String modelVersion;
  final String preprocessVersion;
  final String? failureReason;
  final DateTime createdAt;

  const Prediction({
    required this.id,
    required this.messageId,
    required this.classId,
    required this.crop,
    required this.condition,
    required this.decisionState,
    required this.topLogit,
    required this.calibratedScore,
    required this.margin,
    this.prototypeSimilarity,
    required this.modelVersion,
    required this.preprocessVersion,
    this.failureReason,
    required this.createdAt,
  });

  Prediction copyWith({
    String? id,
    String? messageId,
    int? classId,
    String? crop,
    String? condition,
    DecisionState? decisionState,
    double? topLogit,
    double? calibratedScore,
    double? margin,
    double? prototypeSimilarity,
    String? modelVersion,
    String? preprocessVersion,
    String? failureReason,
    DateTime? createdAt,
  }) {
    return Prediction(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      classId: classId ?? this.classId,
      crop: crop ?? this.crop,
      condition: condition ?? this.condition,
      decisionState: decisionState ?? this.decisionState,
      topLogit: topLogit ?? this.topLogit,
      calibratedScore: calibratedScore ?? this.calibratedScore,
      margin: margin ?? this.margin,
      prototypeSimilarity: prototypeSimilarity ?? this.prototypeSimilarity,
      modelVersion: modelVersion ?? this.modelVersion,
      preprocessVersion: preprocessVersion ?? this.preprocessVersion,
      failureReason: failureReason ?? this.failureReason,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
