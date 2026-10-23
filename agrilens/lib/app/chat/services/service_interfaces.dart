// Minimal abstract interfaces for DiagnosisService and LocalLlmService.
// The pipeline depends on these so tests can provide fakes without
// importing tflite_flutter or llamadart.

import 'diagnosis_result.dart';
import 'local_llm_service.dart';

/// Interface for the on-device leaf classifier.
abstract class DiagnosisServiceInterface {
  bool get isLoaded;
  Future<void> load();
  Future<DiagnosisResult> diagnose(String imagePath);
  void dispose();
}

/// Interface for the local conversational model.
abstract class LlmServiceInterface {
  bool get isReady;
  Future<void> load();
  Future<LlmResult> generateResponse({
    required DiagnosisResult diagnosisResult,
    List<Map<String, String>> priorMessages,
    String? userFollowUp,
    void Function(LlmChunk)? onChunk,
  });
  void cancel();
  void dispose();
}
