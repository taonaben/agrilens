import 'package:dio/dio.dart';

import '../../app/chat/models/prediction.dart' show DecisionState;
import '../api/api_client.dart';
import '../../app/chat/services/diagnosis_result.dart';
import '../../app/chat/services/service_interfaces.dart';

class BackendDiagnosisService implements DiagnosisServiceInterface {
  final BackendApiClient _api;
  CancelToken? _activeRequest;

  BackendDiagnosisService(this._api);

  @override
  bool get isLoaded => true;

  bool get isConfigured => _api.isConfigured;

  @override
  Future<void> load() async {
    // The classifier runs remotely. Do not download or initialize a model on
    // the phone during app startup.
  }

  @override
  Future<DiagnosisResult> diagnose(String imagePath) async {
    if (!isLoaded) {
      return const DiagnosisFailure(
        kind: DiagnosisFailureKind.modelLoadFailed,
        message: 'The AgriLens server URL is not configured.',
      );
    }
    _activeRequest = CancelToken();
    try {
      final json = await _api.postImage(
        '/v1/diagnoses',
        imagePath,
        cancelToken: _activeRequest,
      );
      return _parsePrediction(json);
    } on BackendRequestException catch (error) {
      final kind =
          error.message.contains('decode') || error.message.contains('image')
              ? DiagnosisFailureKind.imageDecodeFailed
              : DiagnosisFailureKind.inferenceFailed;
      return DiagnosisFailure(kind: kind, message: error.message);
    } on DioException catch (error) {
      return DiagnosisFailure(
        kind: DiagnosisFailureKind.inferenceFailed,
        message:
            CancelToken.isCancel(error)
                ? 'Analysis was cancelled.'
                : 'Could not reach the AgriLens server. Please retry.',
      );
    } finally {
      _activeRequest = null;
    }
  }

  DiagnosisResult _parsePrediction(Map<String, dynamic> json) {
    try {
      final classId = json['class_id'] as int;
      final classEntry = ClassMap.byId(classId);
      if (classEntry == null ||
          json['crop'] != classEntry.crop ||
          json['condition'] != classEntry.condition) {
        throw const FormatException('Prediction did not match the class map.');
      }
      final decision = json['decision_state'] as String;
      final score = (json['calibrated_score'] as num).toDouble();
      final margin = (json['margin'] as num).toDouble();
      final reason = json['failure_reason'] as String?;
      if (decision == 'possible_match') {
        return DiagnosisMatch(
          classEntry: classEntry,
          decisionState: DecisionState.possibleMatch,
          topLogit: (json['top_logit'] as num).toDouble(),
          calibratedScore: score,
          margin: margin,
          prototypeSimilarity: json['prototype_similarity'] as double?,
        );
      }
      if (decision == 'uncertain' || decision == 'unsupported_or_unclear') {
        return DiagnosisUncertain(
          topClass: classEntry,
          calibratedScore: score,
          margin: margin,
          reason: reason ?? 'The server marked this result as uncertain.',
        );
      }
      throw const FormatException(
        'Prediction contains an unknown decision state.',
      );
    } on Object catch (error) {
      return DiagnosisFailure(
        kind: DiagnosisFailureKind.outputLayoutMismatch,
        message: 'The server returned an invalid prediction: $error',
      );
    }
  }

  void cancel() {
    _activeRequest?.cancel('Diagnosis cancelled by the user.');
  }

  @override
  void dispose() => cancel();
}
