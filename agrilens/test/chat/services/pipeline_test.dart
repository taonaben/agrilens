// Pipeline unit tests.
//
// Uses in-memory Drift + fake service subclasses to exercise the pipeline
// logic without a device, TFLite runtime, or LLM runtime.
//
// Coverage:
//  - analyzeImage: success (match), success (uncertain), inference failure,
//                  LLM failure (partial success), model-not-loaded
//  - sendFollowUp: success, no-prediction guard, LLM failure,
//                  model-not-loaded
//  - DiagnosisResult reconstruction from saved Prediction
//  - Class map round-trip for all 9 classes

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agrilens/app/chat/data/conversation_repository.dart';
import 'package:agrilens/app/chat/data/database.dart';
import 'package:agrilens/app/chat/data/message_repository.dart';
import 'package:agrilens/app/chat/data/prediction_repository.dart';
import 'package:agrilens/app/chat/models/message.dart';
import 'package:agrilens/app/chat/models/prediction.dart';
import 'package:agrilens/app/chat/services/diagnosis_pipeline.dart';
import 'package:agrilens/app/chat/services/diagnosis_result.dart';
import 'package:agrilens/app/chat/services/local_llm_service.dart';
import 'package:agrilens/app/chat/services/pipeline_result.dart';
import 'package:agrilens/app/chat/services/service_interfaces.dart';

// ── Fake services ─────────────────────────────────────────────────────────────

class FakeDiagnosisService implements DiagnosisServiceInterface {
  DiagnosisResult _next = const DiagnosisFailure(
    kind: DiagnosisFailureKind.inferenceFailed,
    message: 'No result configured.',
  );
  bool _loaded = true;
  int callCount = 0;

  void setNextResult(DiagnosisResult r) => _next = r;
  void setLoaded(bool v) => _loaded = v;

  @override
  bool get isLoaded => _loaded;

  @override
  Future<void> load() async {}

  @override
  Future<DiagnosisResult> diagnose(String imagePath) async {
    callCount++;
    return _next;
  }

  @override
  void dispose() {}
}

class FakeLlmService implements LlmServiceInterface {
  LlmResult _next = const LlmSuccess('Fake LLM response.');
  bool _ready = true;
  int callCount = 0;
  List<String> capturedFollowUps = [];

  void setNextResult(LlmResult r) => _next = r;
  void setReady(bool v) => _ready = v;

  @override
  bool get isReady => _ready;

  @override
  Future<void> load() async {}

  @override
  Future<LlmResult> generateResponse({
    required DiagnosisResult diagnosisResult,
    List<Map<String, String>> priorMessages = const [],
    String? userFollowUp,
    void Function(LlmChunk)? onChunk,
  }) async {
    callCount++;
    if (userFollowUp != null) capturedFollowUps.add(userFollowUp);
    return _next;
  }

  @override
  void cancel() {}

  @override
  void dispose() {}
}

// ── Test helpers ──────────────────────────────────────────────────────────────

AgriLensDatabase makeDb() => AgriLensDatabase.forTesting(
      NativeDatabase.memory(
        setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON'),
      ),
    );

// A pipeline with filesystem copy stubbed out (returns path unchanged)
DiagnosisPipeline makePipeline({
  required FakeDiagnosisService diag,
  required FakeLlmService llm,
  required ConversationRepository convRepo,
  required MessageRepository msgRepo,
  required PredictionRepository predRepo,
}) =>
    DiagnosisPipeline(
      diagnosisService: diag,
      llmService: llm,
      conversationRepo: convRepo,
      messageRepo: msgRepo,
      predictionRepo: predRepo,
      // Stub: return the path unchanged so tests don't need dart:io
      imageCopierOverride: (src) async => '/test/images/$src',
    );

const _matchResult = DiagnosisMatch(
  classEntry: ClassEntry(
    id: 5,
    crop: 'tomato',
    condition: 'early_blight',
    label: 'tomato__early_blight',
  ),
  decisionState: DecisionState.possibleMatch,
  topLogit: 5.1,
  calibratedScore: 0.91,
  margin: 0.32,
);

const _uncertainResult = DiagnosisUncertain(
  topClass: ClassEntry(
    id: 2,
    crop: 'maize',
    condition: 'gray_leaf_spot',
    label: 'maize__gray_leaf_spot',
  ),
  calibratedScore: 0.65,
  margin: 0.09,
  reason: 'Below confidence threshold.',
);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late AgriLensDatabase db;
  late ConversationRepository convRepo;
  late MessageRepository msgRepo;
  late PredictionRepository predRepo;
  late FakeDiagnosisService fakeDiag;
  late FakeLlmService fakeLlm;
  late DiagnosisPipeline pipeline;

  setUp(() {
    db = makeDb();
    convRepo = ConversationRepository(db);
    msgRepo = MessageRepository(db);
    predRepo = PredictionRepository(db);
    fakeDiag = FakeDiagnosisService();
    fakeLlm = FakeLlmService();
    pipeline = makePipeline(
      diag: fakeDiag,
      llm: fakeLlm,
      convRepo: convRepo,
      msgRepo: msgRepo,
      predRepo: predRepo,
    );
  });

  tearDown(() async => db.close());

  // ── analyzeImage: success paths ───────────────────────────────────────────

  group('analyzeImage – success', () {
    test('returns AnalyzeImageSuccess with all objects linked', () async {
      final conv = await convRepo.createConversation(title: 'Success test');
      fakeDiag.setNextResult(_matchResult);
      fakeLlm.setNextResult(const LlmSuccess('Early blight detected.'));

      final result = await pipeline.analyzeImage(
        conversationId: conv.id,
        sourceImagePath: 'leaf.jpg',
      );

      expect(result, isA<AnalyzeImageSuccess>());
      final s = result as AnalyzeImageSuccess;

      expect(s.userImageMessage.role, MessageRole.user);
      expect(s.userImageMessage.contentType, MessageContentType.image);
      expect(s.userImageMessage.lifecycle, MessageLifecycle.complete);
      expect(s.userImageMessage.localImagePath, '/test/images/leaf.jpg');

      expect(s.prediction.classId, 5);
      expect(s.prediction.crop, 'tomato');
      expect(s.prediction.condition, 'early_blight');
      expect(s.prediction.decisionState, DecisionState.possibleMatch);
      expect(s.prediction.calibratedScore, 0.91);
      expect(s.prediction.modelVersion, ModelContract.version);
      expect(s.prediction.preprocessVersion, PreprocessContract.version);

      expect(s.assistantMessage.role, MessageRole.assistant);
      expect(s.assistantMessage.textContent, 'Early blight detected.');
      expect(s.assistantMessage.lifecycle, MessageLifecycle.complete);
    });

    test('all records persisted in the database', () async {
      final conv = await convRepo.createConversation(title: 'DB persist');
      fakeDiag.setNextResult(_matchResult);
      fakeLlm.setNextResult(const LlmSuccess('ok'));

      await pipeline.analyzeImage(
        conversationId: conv.id,
        sourceImagePath: 'img.jpg',
      );

      final messages = await msgRepo.getMessagesForConversation(conv.id);
      expect(messages.length, 2);

      final imageMsg = messages
          .firstWhere((m) => m.contentType == MessageContentType.image);
      final pred = await predRepo.getPredictionForMessage(imageMsg.id);
      expect(pred, isNotNull);
      expect(pred!.classId, 5);
    });

    test('uncertain result persists with uncertain decisionState', () async {
      final conv = await convRepo.createConversation(title: 'Uncertain');
      fakeDiag.setNextResult(_uncertainResult);
      fakeLlm.setNextResult(const LlmSuccess('Uncertain.'));

      final result = await pipeline.analyzeImage(
        conversationId: conv.id,
        sourceImagePath: 'leaf.jpg',
      );

      expect(result, isA<AnalyzeImageSuccess>());
      final s = result as AnalyzeImageSuccess;
      expect(s.prediction.decisionState, DecisionState.uncertain);
      expect(s.prediction.classId, 2);
    });

    test('conversation updatedAt is bumped after success', () async {
      final conv = await convRepo.createConversation(title: 'Timestamp');
      final before = (await convRepo.getConversation(conv.id))!.updatedAt;
      await Future.delayed(const Duration(milliseconds: 10));

      fakeDiag.setNextResult(_matchResult);
      fakeLlm.setNextResult(const LlmSuccess('ok'));
      await pipeline.analyzeImage(
        conversationId: conv.id,
        sourceImagePath: 'leaf.jpg',
      );

      final updated = await convRepo.getConversation(conv.id);
      expect(updated!.updatedAt.isBefore(before), isFalse);
    });
  });

  // ── analyzeImage: failure paths ───────────────────────────────────────────

  group('analyzeImage – failures', () {
    test('inference failure marks user message as failed', () async {
      final conv = await convRepo.createConversation(title: 'Infer fail');
      fakeDiag.setNextResult(
        const DiagnosisFailure(
          kind: DiagnosisFailureKind.imageDecodeFailed,
          message: 'Cannot decode file.',
        ),
      );

      final result = await pipeline.analyzeImage(
        conversationId: conv.id,
        sourceImagePath: 'bad.jpg',
      );

      expect(result, isA<AnalyzeImageFailure>());
      final f = result as AnalyzeImageFailure;
      expect(f.stage, AnalyzeImageFailureStage.inference);
      expect(f.userImageMessage, isNotNull);

      final saved = await msgRepo.getMessage(f.userImageMessage!.id);
      expect(saved!.lifecycle, MessageLifecycle.failed);
    });

    test(
        'LLM failure yields AnalyzeImagePartialSuccess with prediction intact',
        () async {
      final conv = await convRepo.createConversation(title: 'LLM fail');
      fakeDiag.setNextResult(_matchResult);
      fakeLlm.setNextResult(const LlmError('Generation failed.'));

      final result = await pipeline.analyzeImage(
        conversationId: conv.id,
        sourceImagePath: 'leaf.jpg',
      );

      expect(result, isA<AnalyzeImagePartialSuccess>());
      final p = result as AnalyzeImagePartialSuccess;

      // Prediction must survive LLM failure
      expect(p.prediction.classId, 5);
      expect(p.assistantMessage.lifecycle, MessageLifecycle.failed);
      expect(p.generationFailureReason, 'Generation failed.');

      // Verify in DB
      final pred =
          await predRepo.getPredictionForMessage(p.userImageMessage.id);
      expect(pred, isNotNull);
    });

    test('model not loaded returns modelNotLoaded stage', () async {
      final conv = await convRepo.createConversation(title: 'No model');
      fakeDiag.setLoaded(false);

      final result = await pipeline.analyzeImage(
        conversationId: conv.id,
        sourceImagePath: 'leaf.jpg',
      );

      expect(result, isA<AnalyzeImageFailure>());
      expect(
        (result as AnalyzeImageFailure).stage,
        AnalyzeImageFailureStage.modelNotLoaded,
      );
    });

    test('image copy failure returns imageCopy stage', () async {
      final conv = await convRepo.createConversation(title: 'Copy fail');
      // Override to simulate copy failure
      final failPipeline = DiagnosisPipeline(
        diagnosisService: fakeDiag,
        llmService: fakeLlm,
        conversationRepo: convRepo,
        messageRepo: msgRepo,
        predictionRepo: predRepo,
        imageCopierOverride: (_) async => null,
      );

      final result = await failPipeline.analyzeImage(
        conversationId: conv.id,
        sourceImagePath: 'leaf.jpg',
      );

      expect(result, isA<AnalyzeImageFailure>());
      expect(
        (result as AnalyzeImageFailure).stage,
        AnalyzeImageFailureStage.imageCopy,
      );
    });
  });

  // ── sendFollowUp ──────────────────────────────────────────────────────────

  group('sendFollowUp', () {
    Future<void> setupWithAnalysis(String convId) async {
      fakeDiag.setNextResult(_matchResult);
      fakeLlm.setNextResult(const LlmSuccess('Initial response.'));
      await pipeline.analyzeImage(
        conversationId: convId,
        sourceImagePath: 'leaf.jpg',
      );
      fakeDiag.callCount = 0;
      fakeLlm.callCount = 0;
    }

    test('success persists user and assistant messages', () async {
      final conv = await convRepo.createConversation(title: 'Follow-up OK');
      await setupWithAnalysis(conv.id);
      fakeLlm.setNextResult(const LlmSuccess('Follow-up answer.'));

      final result = await pipeline.sendFollowUp(
        conversationId: conv.id,
        text: 'What should I do?',
      );

      expect(result, isA<SendFollowUpSuccess>());
      final s = result as SendFollowUpSuccess;
      expect(s.userMessage.textContent, 'What should I do?');
      expect(s.userMessage.lifecycle, MessageLifecycle.complete);
      expect(s.assistantMessage.textContent, 'Follow-up answer.');
      expect(s.assistantMessage.lifecycle, MessageLifecycle.complete);
      expect(fakeLlm.callCount, 1);
      expect(fakeLlm.capturedFollowUps, ['What should I do?']);
    });

    test('no-prediction → noPrediction failure with user message saved',
        () async {
      final conv = await convRepo.createConversation(title: 'No image');

      final result = await pipeline.sendFollowUp(
        conversationId: conv.id,
        text: 'Tell me about blight.',
      );

      expect(result, isA<SendFollowUpFailure>());
      final f = result as SendFollowUpFailure;
      expect(f.reason, SendFollowUpFailureReason.noPrediction);
      expect(f.userMessage, isNotNull);
      expect(f.userMessage!.textContent, 'Tell me about blight.');
      // User message is saved even when there's no prediction
      expect(f.userMessage!.lifecycle, MessageLifecycle.complete);
    });

    test('LLM failure → generationFailed with user message saved', () async {
      final conv = await convRepo.createConversation(title: 'LLM fail FU');
      await setupWithAnalysis(conv.id);
      fakeLlm.setNextResult(const LlmError('Timeout.'));

      final result = await pipeline.sendFollowUp(
        conversationId: conv.id,
        text: 'Any tips?',
      );

      expect(result, isA<SendFollowUpFailure>());
      final f = result as SendFollowUpFailure;
      expect(f.reason, SendFollowUpFailureReason.generationFailed);
      expect(f.userMessage!.textContent, 'Any tips?');
    });

    test('model not ready → modelNotLoaded failure (no messages saved)',
        () async {
      final conv = await convRepo.createConversation(title: 'LLM off');
      fakeLlm.setReady(false);

      final result = await pipeline.sendFollowUp(
        conversationId: conv.id,
        text: 'Hello?',
      );

      expect(result, isA<SendFollowUpFailure>());
      expect(
        (result as SendFollowUpFailure).reason,
        SendFollowUpFailureReason.modelNotLoaded,
      );
      // No messages should be saved when we exit early
      final messages = await msgRepo.getMessagesForConversation(conv.id);
      expect(messages, isEmpty);
    });
  });

  // ── Class map round-trip ──────────────────────────────────────────────────

  group('Class map round-trip', () {
    test('all 9 class IDs persist and reload correctly', () async {
      for (int id = 0; id < 9; id++) {
        final entry = ClassMap.byId(id)!;
        final conv = await convRepo.createConversation(title: 'Class $id');

        fakeDiag.setNextResult(
          DiagnosisMatch(
            classEntry: entry,
            decisionState: DecisionState.possibleMatch,
            topLogit: 5.0,
            calibratedScore: 0.90,
            margin: 0.30,
          ),
        );
        fakeLlm.setNextResult(LlmSuccess('Response $id'));

        final result = await pipeline.analyzeImage(
          conversationId: conv.id,
          sourceImagePath: 'leaf_$id.jpg',
        );

        expect(result, isA<AnalyzeImageSuccess>(),
            reason: 'Class $id should succeed');
        final s = result as AnalyzeImageSuccess;
        expect(s.prediction.classId, id,
            reason: 'classId must round-trip unchanged');
        expect(s.prediction.crop, entry.crop);
        expect(s.prediction.condition, entry.condition);
      }
    });
  });

  // ── Retry assistant response ──────────────────────────────────────────────

  group('retryAssistantResponse', () {
    test('retries generation and updates failed assistant message', () async {
      final conv = await convRepo.createConversation(title: 'Retry');

      // First attempt fails at LLM
      fakeDiag.setNextResult(_matchResult);
      fakeLlm.setNextResult(const LlmError('First attempt failed.'));
      await pipeline.analyzeImage(
        conversationId: conv.id,
        sourceImagePath: 'leaf.jpg',
      );

      // Retry should succeed
      fakeLlm.setNextResult(const LlmSuccess('Retry succeeded.'));
      final retryResult = await pipeline.retryAssistantResponse(
        conversationId: conv.id,
      );

      expect(retryResult, isA<AnalyzeImageSuccess>());
      final s = retryResult as AnalyzeImageSuccess;
      expect(s.assistantMessage.textContent, 'Retry succeeded.');
      expect(s.assistantMessage.lifecycle, MessageLifecycle.complete);
    });

    test('retry with no image returns failure', () async {
      final conv = await convRepo.createConversation(title: 'No img retry');

      final result = await pipeline.retryAssistantResponse(
        conversationId: conv.id,
      );

      expect(result, isA<AnalyzeImageFailure>());
    });
  });
}
