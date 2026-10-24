// Typed result contract for the DiagnosisPipeline.
// These types are what the Chat UI observes — they carry no tensor logic.

import '../models/message.dart';
import '../models/prediction.dart';

/// Outcome of [DiagnosisPipeline.analyzeImage].
sealed class AnalyzeImageResult {
  const AnalyzeImageResult();
}

/// Full pipeline completed successfully.
/// Both the prediction and the assistant message are persisted.
class AnalyzeImageSuccess extends AnalyzeImageResult {
  final MessageModel userImageMessage;
  final Prediction prediction;
  final MessageModel assistantMessage;

  const AnalyzeImageSuccess({
    required this.userImageMessage,
    required this.assistantMessage,
    required this.prediction,
  });
}

/// Classifier ran but the LLM generation failed or was cancelled.
/// The prediction IS persisted; only the assistant response is missing.
/// The caller may retry generation separately via [DiagnosisPipeline.retryAssistantResponse].
class AnalyzeImagePartialSuccess extends AnalyzeImageResult {
  final MessageModel userImageMessage;
  final Prediction prediction;

  /// The failed/cancelled assistant message (lifecycle = failed/pending)
  final MessageModel assistantMessage;

  final String generationFailureReason;

  const AnalyzeImagePartialSuccess({
    required this.userImageMessage,
    required this.prediction,
    required this.assistantMessage,
    required this.generationFailureReason,
  });
}

/// Pipeline failed before or during inference.
/// The user message may or may not be persisted, depending on [stage].
class AnalyzeImageFailure extends AnalyzeImageResult {
  final AnalyzeImageFailureStage stage;
  final String message;

  /// The persisted user message if it was saved before failure, else null.
  final MessageModel? userImageMessage;

  const AnalyzeImageFailure({
    required this.stage,
    required this.message,
    this.userImageMessage,
  });
}

enum AnalyzeImageFailureStage {
  /// Could not copy the image file to app-owned storage
  imageCopy,

  /// Image saved; classifier could not decode or process it
  inference,

  /// Model not loaded when analyzeImage was called
  modelNotLoaded,
}

// ────────────────────────────────────────────────────────────────────────────

/// Outcome of [DiagnosisPipeline.sendFollowUp].
sealed class SendFollowUpResult {
  const SendFollowUpResult();
}

/// Follow-up succeeded; both messages persisted.
class SendFollowUpSuccess extends SendFollowUpResult {
  final MessageModel userMessage;
  final MessageModel assistantMessage;

  const SendFollowUpSuccess({
    required this.userMessage,
    required this.assistantMessage,
  });
}

/// Pipeline failed or was cancelled.
class SendFollowUpFailure extends SendFollowUpResult {
  final SendFollowUpFailureReason reason;
  final String message;

  /// The persisted user message, if it was saved before failure
  final MessageModel? userMessage;

  const SendFollowUpFailure({
    required this.reason,
    required this.message,
    this.userMessage,
  });
}

enum SendFollowUpFailureReason {
  /// No prediction exists for this conversation; user must submit a photo first
  noPrediction,

  /// LLM not loaded
  modelNotLoaded,

  /// Generation error or cancellation
  generationFailed,
}
