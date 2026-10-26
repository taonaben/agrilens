import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../../app/chat/services/diagnosis_result.dart';
import '../../app/chat/services/local_llm_service.dart'
    show LlmCancelled, LlmChunk, LlmError, LlmResult, LlmSuccess;
import '../../app/chat/services/service_interfaces.dart';

class BackendLlmService implements LlmServiceInterface {
  final ApiClient _api;
  CancelToken? _activeRequest;
  bool _disposed = false;

  BackendLlmService(this._api);

  @override
  bool get isReady => !_disposed;

  @override
  Future<void> load() async {
    // Gemini is called by FastAPI. No conversational model is loaded on-device.
  }

  @override
  Future<LlmResult> generateResponse({
    required DiagnosisResult diagnosisResult,
    List<Map<String, String>> priorMessages = const [],
    String? userFollowUp,
    void Function(LlmChunk)? onChunk,
  }) async {
    final prediction = _predictionPayload(diagnosisResult);
    if (prediction == null) {
      return const LlmError('A supported classifier result is required first.');
    }
    _activeRequest = CancelToken();
    try {
      final response = await _api.postJson('/v1/answers', {
        'prediction': prediction,
        'prior_messages': priorMessages,
        'user_follow_up': userFollowUp,
      }, cancelToken: _activeRequest);
      final text = response['answer'];
      if (text is! String || text.trim().isEmpty) {
        return const LlmError('The server returned an empty answer.');
      }
      onChunk?.call(LlmChunk(text));
      return LlmSuccess(text);
    } on ApiRequestException catch (error) {
      return LlmError(error.message);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) return const LlmCancelled();
      return const LlmError('The answer request failed. Please retry.');
    } finally {
      _activeRequest = null;
    }
  }

  Map<String, dynamic>? _predictionPayload(DiagnosisResult result) {
    switch (result) {
      case DiagnosisMatch(
        :final classEntry,
        :final decisionState,
        :final topLogit,
        :final calibratedScore,
        :final margin,
        :final prototypeSimilarity,
      ):
        return {
          'class_id': classEntry.id,
          'crop': classEntry.crop,
          'condition': classEntry.condition,
          'decision_state':
              decisionState.name == 'possibleMatch'
                  ? 'possible_match'
                  : 'uncertain',
          'top_logit': topLogit,
          'calibrated_score': calibratedScore,
          'margin': margin,
          'prototype_similarity': prototypeSimilarity,
          'model_version': ModelContract.version,
          'preprocess_version': PreprocessContract.version,
        };
      case DiagnosisUncertain(
        :final topClass,
        :final calibratedScore,
        :final margin,
        :final reason,
      ):
        return {
          'class_id': topClass.id,
          'crop': topClass.crop,
          'condition': topClass.condition,
          'decision_state': 'uncertain',
          'top_logit': 0.0,
          'calibrated_score': calibratedScore,
          'margin': margin,
          'prototype_similarity': null,
          'model_version': ModelContract.version,
          'preprocess_version': PreprocessContract.version,
          'failure_reason': reason,
        };
      case DiagnosisFailure():
        return null;
    }
  }

  @override
  void cancel() => _activeRequest?.cancel('Answer request cancelled by user.');

  @override
  void dispose() {
    cancel();
    _disposed = true;
  }
}
