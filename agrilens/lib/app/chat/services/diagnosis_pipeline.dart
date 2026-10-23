// Diagnosis pipeline: orchestrates image copy → classifier → LLM → DB writes.
//
// This is the single entry point the Chat UI calls. It keeps all service
// coordination and error handling out of widgets.
//
// analyzeImage:
//   1. Copy image to app-owned storage
//   2. Save pending user-image message
//   3. Run TFLite classifier
//   4. Persist prediction + mark message complete (atomic, even if LLM fails)
//   5. Save pending assistant message
//   6. Generate LLM response
//   7. Persist assistant text + mark complete (or failed)
//
// sendFollowUp:
//   1. Load conversation messages and find the prediction context
//   2. Save pending user-text message
//   3. Generate LLM response using saved prediction context
//   4. Persist assistant text + mark complete (or failed)

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../data/conversation_repository.dart';
import '../data/message_repository.dart';
import '../data/prediction_repository.dart';
import '../models/message.dart';
import '../models/prediction.dart';
import '../services/diagnosis_result.dart';
import '../services/local_llm_service.dart';
import '../services/pipeline_result.dart';
import '../services/service_interfaces.dart';

class DiagnosisPipeline {
  final DiagnosisServiceInterface _diagnosisService;
  final LlmServiceInterface _llmService;
  final ConversationRepository _conversationRepo;
  final MessageRepository _messageRepo;
  final PredictionRepository _predictionRepo;

  /// Optional override for image copying — used in tests to avoid filesystem.
  final Future<String?> Function(String)? _imageCopierOverride;

  final _uuid = const Uuid();

  DiagnosisPipeline({
    required DiagnosisServiceInterface diagnosisService,
    required LlmServiceInterface llmService,
    required ConversationRepository conversationRepo,
    required MessageRepository messageRepo,
    required PredictionRepository predictionRepo,
    Future<String?> Function(String sourcePath)? imageCopierOverride,
  })  : _diagnosisService = diagnosisService,
        _llmService = llmService,
        _conversationRepo = conversationRepo,
        _messageRepo = messageRepo,
        _predictionRepo = predictionRepo,
        _imageCopierOverride = imageCopierOverride;

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Analyse an image and generate an assistant response.
  ///
  /// [conversationId] must already exist in the database.
  /// [sourceImagePath] is the user-chosen file (camera or gallery).
  ///
  /// Returns:
  /// - [AnalyzeImageSuccess]         – both prediction and assistant text persisted
  /// - [AnalyzeImagePartialSuccess]  – prediction saved, LLM failed (retryable)
  /// - [AnalyzeImageFailure]         – early failure (image copy or inference)
  ///
  /// The prediction is ALWAYS persisted before the LLM runs, so a generation
  /// failure never loses the classifier result.
  Future<AnalyzeImageResult> analyzeImage({
    required String conversationId,
    required String sourceImagePath,
    void Function(LlmChunk)? onChunk,
  }) async {
    // ── Step 1: Copy image to app-owned storage ─────────────────────────────
    final String? ownedPath =
        await _copyImageToAppStorage(sourceImagePath);
    if (ownedPath == null) {
      return const AnalyzeImageFailure(
        stage: AnalyzeImageFailureStage.imageCopy,
        message:
            'Could not save the image to app storage. '
            'Please check available space and try again.',
      );
    }

    // ── Step 2: Save pending user-image message ──────────────────────────────
    final Message userMsg = await _messageRepo.createMessage(
      conversationId: conversationId,
      role: MessageRole.user,
      contentType: MessageContentType.image,
      localImagePath: ownedPath,
      lifecycle: MessageLifecycle.pending,
    );

    // ── Step 3: Run classifier ───────────────────────────────────────────────
    if (!_diagnosisService.isLoaded) {
      await _messageRepo.markMessageFailed(
        userMsg.id,
        'Classifier not loaded.',
      );
      return AnalyzeImageFailure(
        stage: AnalyzeImageFailureStage.modelNotLoaded,
        message: 'The diagnosis model is not ready. Please restart the app.',
        userImageMessage: userMsg,
      );
    }

    final DiagnosisResult diagnosisResult =
        await _diagnosisService.diagnose(ownedPath);

    // ── Step 4: Persist prediction + mark message complete (or failed) ───────
    final prediction = await _persistPredictionFromResult(
      conversationId: conversationId,
      messageId: userMsg.id,
      diagnosisResult: diagnosisResult,
    );

    if (prediction == null) {
      // Inference-level failure (image decode, inference error, etc.)
      // Message is already marked failed inside _persistPredictionFromResult
      final updatedUserMsg = await _messageRepo.getMessage(userMsg.id) ?? userMsg;
      return AnalyzeImageFailure(
        stage: AnalyzeImageFailureStage.inference,
        message: _failureMessage(diagnosisResult),
        userImageMessage: updatedUserMsg,
      );
    }

    // ── Step 5: Save pending assistant message ───────────────────────────────
    final Message assistantMsg = await _messageRepo.createMessage(
      conversationId: conversationId,
      role: MessageRole.assistant,
      contentType: MessageContentType.text,
      lifecycle: MessageLifecycle.pending,
    );

    // ── Step 6 + 7: Generate and persist LLM response ────────────────────────
    final result = await _generateAndPersistAssistantResponse(
      conversationId: conversationId,
      assistantMessageId: assistantMsg.id,
      diagnosisResult: diagnosisResult,
      priorMessages: const [],
      onChunk: onChunk,
    );

    final updatedUserMsg = await _messageRepo.getMessage(userMsg.id) ?? userMsg;
    final updatedAssistantMsg =
        await _messageRepo.getMessage(assistantMsg.id) ?? assistantMsg;

    return switch (result) {
      _LlmPersistSuccess() => AnalyzeImageSuccess(
          userImageMessage: updatedUserMsg,
          prediction: prediction,
          assistantMessage: updatedAssistantMsg,
        ),
      _LlmPersistFailure(:final reason) => AnalyzeImagePartialSuccess(
          userImageMessage: updatedUserMsg,
          prediction: prediction,
          assistantMessage: updatedAssistantMsg,
          generationFailureReason: reason,
        ),
    };
  }

  /// Retry generating an assistant response for a conversation where the
  /// prediction is already saved but generation failed.
  ///
  /// Finds the most recent failed/pending assistant message and replaces it
  /// with a new generation attempt. If no prior prediction exists, returns a
  /// failure indicating the user needs to submit a photo first.
  Future<AnalyzeImageResult> retryAssistantResponse({
    required String conversationId,
    void Function(LlmChunk)? onChunk,
  }) async {
    final messages =
        await _messageRepo.getMessagesForConversation(conversationId);

    // Find the most recent user-image message
    final imageMessages = messages
        .where(
          (m) =>
              m.role == MessageRole.user &&
              m.contentType == MessageContentType.image,
        )
        .toList();

    if (imageMessages.isEmpty) {
      return const AnalyzeImageFailure(
        stage: AnalyzeImageFailureStage.inference,
        message: 'No image found in this conversation. Please take a photo first.',
      );
    }

    final lastImageMsg = imageMessages.last;
    final prediction =
        await _predictionRepo.getPredictionForMessage(lastImageMsg.id);

    if (prediction == null) {
      return AnalyzeImageFailure(
        stage: AnalyzeImageFailureStage.inference,
        message: 'No analysis result found for the image.',
        userImageMessage: lastImageMsg,
      );
    }

    // Create a fresh pending assistant message (or reuse existing failed one)
    final failedAssistant = messages
        .where(
          (m) =>
              m.role == MessageRole.assistant &&
              m.lifecycle == MessageLifecycle.failed,
        )
        .lastOrNull;

    final String assistantMessageId;
    if (failedAssistant != null) {
      assistantMessageId = failedAssistant.id;
      await _messageRepo.updateMessageLifecycle(
        failedAssistant.id,
        MessageLifecycle.pending,
      );
    } else {
      final newMsg = await _messageRepo.createMessage(
        conversationId: conversationId,
        role: MessageRole.assistant,
        contentType: MessageContentType.text,
        lifecycle: MessageLifecycle.pending,
      );
      assistantMessageId = newMsg.id;
    }

    final diagnosisResult = _reconstructDiagnosisResult(prediction);
    final priorMessages = _buildPriorMessages(messages);

    final llmResult = await _generateAndPersistAssistantResponse(
      conversationId: conversationId,
      assistantMessageId: assistantMessageId,
      diagnosisResult: diagnosisResult,
      priorMessages: priorMessages,
      onChunk: onChunk,
    );

    final updatedAssistantMsg =
        await _messageRepo.getMessage(assistantMessageId);

    return switch (llmResult) {
      _LlmPersistSuccess() => AnalyzeImageSuccess(
          userImageMessage: lastImageMsg,
          prediction: prediction,
          assistantMessage: updatedAssistantMsg!,
        ),
      _LlmPersistFailure(:final reason) => AnalyzeImagePartialSuccess(
          userImageMessage: lastImageMsg,
          prediction: prediction,
          assistantMessage: updatedAssistantMsg!,
          generationFailureReason: reason,
        ),
    };
  }

  /// Send a follow-up text question about the existing prediction.
  ///
  /// If no prediction exists for this conversation, returns a failure
  /// explaining that a photo is needed first.
  Future<SendFollowUpResult> sendFollowUp({
    required String conversationId,
    required String text,
    void Function(LlmChunk)? onChunk,
  }) async {
    if (!_llmService.isReady) {
      return const SendFollowUpFailure(
        reason: SendFollowUpFailureReason.modelNotLoaded,
        message: 'The conversation model is not ready. Please wait.',
      );
    }

    // ── Load conversation context ────────────────────────────────────────────
    final messages =
        await _messageRepo.getMessagesForConversation(conversationId);

    // Find prediction from the most recent image message
    final imageMessage = messages
        .where(
          (m) =>
              m.role == MessageRole.user &&
              m.contentType == MessageContentType.image,
        )
        .lastOrNull;

    Prediction? prediction;
    if (imageMessage != null) {
      prediction =
          await _predictionRepo.getPredictionForMessage(imageMessage.id);
    }

    if (prediction == null) {
      // Save the user's question so it appears in the UI even without a prediction
      final userMsg = await _messageRepo.createMessage(
        conversationId: conversationId,
        role: MessageRole.user,
        contentType: MessageContentType.text,
        textContent: text,
        lifecycle: MessageLifecycle.complete,
      );
      return SendFollowUpFailure(
        reason: SendFollowUpFailureReason.noPrediction,
        message:
            'Please take or select a leaf photo first. '
            'The app needs an image to analyse before answering questions.',
        userMessage: userMsg,
      );
    }

    // ── Save pending user text message ───────────────────────────────────────
    final userMsg = await _messageRepo.createMessage(
      conversationId: conversationId,
      role: MessageRole.user,
      contentType: MessageContentType.text,
      textContent: text,
      lifecycle: MessageLifecycle.complete,
    );

    // ── Save pending assistant message ───────────────────────────────────────
    final assistantMsg = await _messageRepo.createMessage(
      conversationId: conversationId,
      role: MessageRole.assistant,
      contentType: MessageContentType.text,
      lifecycle: MessageLifecycle.pending,
    );

    // ── Reconstruct DiagnosisResult and build prior context ──────────────────
    final diagnosisResult = _reconstructDiagnosisResult(prediction);
    final priorMessages = _buildPriorMessages(messages);

    // ── Generate and persist response ────────────────────────────────────────
    final llmResult = await _generateAndPersistAssistantResponse(
      conversationId: conversationId,
      assistantMessageId: assistantMsg.id,
      diagnosisResult: diagnosisResult,
      priorMessages: priorMessages,
      userFollowUp: text,
      onChunk: onChunk,
    );

    final updatedAssistant =
        await _messageRepo.getMessage(assistantMsg.id) ?? assistantMsg;

    return switch (llmResult) {
      _LlmPersistSuccess() => SendFollowUpSuccess(
          userMessage: userMsg,
          assistantMessage: updatedAssistant,
        ),
      _LlmPersistFailure(:final reason) => SendFollowUpFailure(
          reason: SendFollowUpFailureReason.generationFailed,
          message: reason,
          userMessage: userMsg,
        ),
    };
  }

  /// Cancel any in-progress LLM generation.
  void cancelGeneration() => _llmService.cancel();

  // ── Internal helpers ────────────────────────────────────────────────────────

  /// Copy [sourcePath] into the app's images directory.
  /// Returns the new path on success, null on failure.
  Future<String?> _copyImageToAppStorage(String sourcePath) async {
    if (_imageCopierOverride != null) return _imageCopierOverride(sourcePath);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${dir.path}/images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final ext = sourcePath.contains('.')
          ? '.${sourcePath.split('.').last}'
          : '.jpg';
      final destPath = '${imagesDir.path}/${_uuid.v4()}$ext';

      await File(sourcePath).copy(destPath);
      return destPath;
    } catch (_) {
      return null;
    }
  }

  /// Persist the prediction from a DiagnosisResult and return it.
  /// Returns null and marks the message failed for DiagnosisFailure.
  Future<Prediction?> _persistPredictionFromResult({
    required String conversationId,
    required String messageId,
    required DiagnosisResult diagnosisResult,
  }) async {
    switch (diagnosisResult) {
      case DiagnosisMatch(
        :final classEntry,
        :final decisionState,
        :final topLogit,
        :final calibratedScore,
        :final margin,
        :final prototypeSimilarity,
      ):
        return _predictionRepo.createPredictionWithMessageUpdate(
          conversationId: conversationId,
          messageId: messageId,
          classId: classEntry.id,
          crop: classEntry.crop,
          condition: classEntry.condition,
          decisionState: _toDomainDecisionState(decisionState),
          topLogit: topLogit,
          calibratedScore: calibratedScore,
          margin: margin,
          prototypeSimilarity: prototypeSimilarity,
          modelVersion: ModelContract.version,
          preprocessVersion: PreprocessContract.version,
        );

      case DiagnosisUncertain(
        :final topClass,
        :final calibratedScore,
        :final margin,
        :final reason,
      ):
        return _predictionRepo.createPredictionWithMessageUpdate(
          conversationId: conversationId,
          messageId: messageId,
          classId: topClass.id,
          crop: topClass.crop,
          condition: topClass.condition,
          decisionState: DecisionState.uncertain,
          topLogit: 0.0, // not stored separately for uncertain results
          calibratedScore: calibratedScore,
          margin: margin,
          modelVersion: ModelContract.version,
          preprocessVersion: PreprocessContract.version,
          failureReason: reason,
        );

      case DiagnosisFailure(:final message):
        await _messageRepo.markMessageFailed(messageId, message);
        return null;
    }
  }

  /// Convert a service-layer [DecisionState] from DiagnosisMatch
  /// (which uses the same-named enum from diagnosis_result.dart imported via
  /// models/prediction.dart) to the domain model [DecisionState].
  ///
  /// Both enums have the same values; this conversion just keeps the
  /// import layers separate.
  DecisionState _toDomainDecisionState(DecisionState ds) => ds;

  /// Internal result of a generate+persist step.
  Future<_LlmPersistResult> _generateAndPersistAssistantResponse({
    required String conversationId,
    required String assistantMessageId,
    required DiagnosisResult diagnosisResult,
    required List<Map<String, String>> priorMessages,
    String? userFollowUp,
    void Function(LlmChunk)? onChunk,
  }) async {
    if (!_llmService.isReady) {
      await _messageRepo.markMessageFailed(
        assistantMessageId,
        'Language model not ready.',
      );
      return const _LlmPersistFailure('Language model is not ready.');
    }

    final llmResult = await _llmService.generateResponse(
      diagnosisResult: diagnosisResult,
      priorMessages: priorMessages,
      userFollowUp: userFollowUp,
      onChunk: onChunk,
    );

    switch (llmResult) {
      case LlmSuccess(:final text):
        await _messageRepo.completeMessageWithText(assistantMessageId, text);
        await _conversationRepo.touchConversation(conversationId);
        return const _LlmPersistSuccess();

      case LlmCancelled():
        await _messageRepo.markMessageFailed(
          assistantMessageId,
          'Response was cancelled.',
        );
        return const _LlmPersistFailure('Generation was cancelled.');

      case LlmError(:final message):
        await _messageRepo.markMessageFailed(assistantMessageId, message);
        return _LlmPersistFailure(message);
    }
  }

  /// Reconstruct a [DiagnosisResult] from a saved [Prediction].
  /// Used for follow-up questions and retry flows.
  DiagnosisResult _reconstructDiagnosisResult(Prediction prediction) {
    final classEntry = ClassMap.byId(prediction.classId);

    if (prediction.failureReason != null || classEntry == null) {
      // Stored as an uncertain/failure result
      if (classEntry == null) {
        return DiagnosisFailure(
          kind: DiagnosisFailureKind.outputLayoutMismatch,
          message:
              'Class ID ${prediction.classId} not found in class map.',
        );
      }
      return DiagnosisUncertain(
        topClass: classEntry,
        calibratedScore: prediction.calibratedScore,
        margin: prediction.margin,
        reason: prediction.failureReason ?? 'Uncertain result',
      );
    }

    switch (prediction.decisionState) {
      case DecisionState.possibleMatch:
        return DiagnosisMatch(
          classEntry: classEntry,
          decisionState: prediction.decisionState,
          topLogit: prediction.topLogit,
          calibratedScore: prediction.calibratedScore,
          margin: prediction.margin,
          prototypeSimilarity: prediction.prototypeSimilarity,
        );
      case DecisionState.uncertain:
      case DecisionState.unsupportedOrUnclear:
        return DiagnosisUncertain(
          topClass: classEntry,
          calibratedScore: prediction.calibratedScore,
          margin: prediction.margin,
          reason:
              'Result was ${prediction.decisionState.name} when first analysed.',
        );
    }
  }

  /// Build a prior-message list for LocalLlmService from DB messages.
  /// Excludes image messages (LLM only sees text) and the most recent
  /// user message (it's passed as userFollowUp instead).
  List<Map<String, String>> _buildPriorMessages(List<Message> messages) {
    return messages
        .where(
          (m) =>
              m.contentType == MessageContentType.text &&
              m.lifecycle == MessageLifecycle.complete &&
              m.textContent != null &&
              m.textContent!.isNotEmpty,
        )
        .map(
          (m) => {
            'role': m.role.name,
            'content': m.textContent!,
          },
        )
        .toList();
  }

  /// Extract a user-facing failure message from a [DiagnosisFailure].
  String _failureMessage(DiagnosisResult result) {
    if (result case DiagnosisFailure(:final message)) return message;
    return 'Analysis did not complete.';
  }
}

// Internal sealed result for the generate+persist step
sealed class _LlmPersistResult {
  const _LlmPersistResult();
}

class _LlmPersistSuccess extends _LlmPersistResult {
  const _LlmPersistSuccess();
}

class _LlmPersistFailure extends _LlmPersistResult {
  final String reason;
  const _LlmPersistFailure(this.reason);
}
