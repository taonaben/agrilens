import 'package:uuid/uuid.dart';
import '../models/prediction.dart' as model;
import '../models/message.dart' as model;
import 'database.dart';

/// Repository for prediction operations
class PredictionRepository {
  final AgriLensDatabase _db;
  final _uuid = const Uuid();

  PredictionRepository(this._db);

  /// Create a new prediction linked to a message
  Future<model.Prediction> createPrediction({
    required String messageId,
    required int classId,
    required String crop,
    required String condition,
    required model.DecisionState decisionState,
    required double topLogit,
    required double calibratedScore,
    required double margin,
    double? prototypeSimilarity,
    required String modelVersion,
    required String preprocessVersion,
    String? failureReason,
  }) async {
    final prediction = model.Prediction(
      id: _uuid.v4(),
      messageId: messageId,
      classId: classId,
      crop: crop,
      condition: condition,
      decisionState: decisionState,
      topLogit: topLogit,
      calibratedScore: calibratedScore,
      margin: margin,
      prototypeSimilarity: prototypeSimilarity,
      modelVersion: modelVersion,
      preprocessVersion: preprocessVersion,
      failureReason: failureReason,
      createdAt: DateTime.now(),
    );

    await _db.createPrediction(_toDbPrediction(prediction));
    return prediction;
  }

  /// Create prediction and update the associated message lifecycle in a transaction
  Future<model.Prediction> createPredictionWithMessageUpdate({
    required String conversationId,
    required String messageId,
    required int classId,
    required String crop,
    required String condition,
    required model.DecisionState decisionState,
    required double topLogit,
    required double calibratedScore,
    required double margin,
    double? prototypeSimilarity,
    required String modelVersion,
    required String preprocessVersion,
    String? failureReason,
  }) async {
    final prediction = model.Prediction(
      id: _uuid.v4(),
      messageId: messageId,
      classId: classId,
      crop: crop,
      condition: condition,
      decisionState: decisionState,
      topLogit: topLogit,
      calibratedScore: calibratedScore,
      margin: margin,
      prototypeSimilarity: prototypeSimilarity,
      modelVersion: modelVersion,
      preprocessVersion: preprocessVersion,
      failureReason: failureReason,
      createdAt: DateTime.now(),
    );

    // Get the message to create a complete Message object for the transaction
    final dbMessage = await _db.getMessage(messageId);
    if (dbMessage == null) {
      throw Exception('Message not found: $messageId');
    }

    final updatedMessage = dbMessage.copyWith(
      lifecycle: model.MessageLifecycle.complete.name,
      updatedAt: DateTime.now(),
    );

    await _db.createMessageWithPrediction(
      conversationId: conversationId,
      message: updatedMessage,
      prediction: _toDbPrediction(prediction),
    );

    return prediction;
  }

  /// Get prediction by ID
  Future<model.Prediction?> getPrediction(String id) async {
    final dbPred = await _db.getPrediction(id);
    return dbPred != null ? _fromDbPrediction(dbPred) : null;
  }

  /// Get prediction for a specific message
  Future<model.Prediction?> getPredictionForMessage(String messageId) async {
    final dbPred = await _db.getPredictionForMessage(messageId);
    return dbPred != null ? _fromDbPrediction(dbPred) : null;
  }

  // Conversion helpers
  Prediction _toDbPrediction(model.Prediction pred) {
    return Prediction(
      id: pred.id,
      messageId: pred.messageId,
      classId: pred.classId,
      crop: pred.crop,
      condition: pred.condition,
      decisionState: pred.decisionState.name,
      topLogit: pred.topLogit,
      calibratedScore: pred.calibratedScore,
      margin: pred.margin,
      prototypeSimilarity: pred.prototypeSimilarity,
      modelVersion: pred.modelVersion,
      preprocessVersion: pred.preprocessVersion,
      failureReason: pred.failureReason,
      createdAt: pred.createdAt,
    );
  }

  model.Prediction _fromDbPrediction(Prediction dbPred) {
    return model.Prediction(
      id: dbPred.id,
      messageId: dbPred.messageId,
      classId: dbPred.classId,
      crop: dbPred.crop,
      condition: dbPred.condition,
      decisionState: _parseDecisionState(dbPred.decisionState),
      topLogit: dbPred.topLogit,
      calibratedScore: dbPred.calibratedScore,
      margin: dbPred.margin,
      prototypeSimilarity: dbPred.prototypeSimilarity,
      modelVersion: dbPred.modelVersion,
      preprocessVersion: dbPred.preprocessVersion,
      failureReason: dbPred.failureReason,
      createdAt: dbPred.createdAt,
    );
  }

  model.DecisionState _parseDecisionState(String state) {
    return model.DecisionState.values.firstWhere(
      (s) => s.name == state,
      orElse: () => model.DecisionState.uncertain,
    );
  }
}
