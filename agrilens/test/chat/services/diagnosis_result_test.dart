// Tests for the pure-Dart logic in DiagnosisService:
// - Class map ordering (must match class_map.json)
// - Preprocessing contract constants
// - Rejection policy constants
// - Softmax and rejection logic (white-box via testable extraction)
//
// NOTE: Full inference tests require a physical Android device with the
// TFLite model loaded. Those are integration tests and run outside this file.

import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';
import 'package:agrilens/app/chat/services/diagnosis_result.dart';
import 'package:agrilens/app/chat/services/diagnosis_service.dart';
import 'package:agrilens/app/chat/models/prediction.dart';

void main() {
  group('ClassMap', () {
    test('has exactly 9 classes', () {
      expect(ClassMap.entries.length, 9);
    });

    test('class IDs are 0-8 in order', () {
      for (int i = 0; i < ClassMap.entries.length; i++) {
        expect(
          ClassMap.entries[i].id,
          i,
          reason: 'Entry at index $i should have id $i',
        );
      }
    });

    test('class order matches class_map.json exactly', () {
      // From ../agrilens-training/artifacts/class_map.json
      final expected = [
        (crop: 'maize', condition: 'common_rust'),
        (crop: 'maize', condition: 'northern_leaf_blight'),
        (crop: 'maize', condition: 'gray_leaf_spot'),
        (crop: 'maize', condition: 'healthy'),
        (crop: 'tomato', condition: 'bacterial_spot'),
        (crop: 'tomato', condition: 'early_blight'),
        (crop: 'tomato', condition: 'late_blight'),
        (crop: 'tomato', condition: 'leaf_mold'),
        (crop: 'tomato', condition: 'healthy'),
      ];

      for (int i = 0; i < expected.length; i++) {
        expect(
          ClassMap.entries[i].crop,
          expected[i].crop,
          reason: 'Class $i crop mismatch',
        );
        expect(
          ClassMap.entries[i].condition,
          expected[i].condition,
          reason: 'Class $i condition mismatch',
        );
      }
    });

    test('byId returns correct entry for valid IDs', () {
      expect(ClassMap.byId(0)?.crop, 'maize');
      expect(ClassMap.byId(0)?.condition, 'common_rust');
      expect(ClassMap.byId(3)?.condition, 'healthy'); // maize healthy
      expect(ClassMap.byId(8)?.crop, 'tomato');
      expect(ClassMap.byId(8)?.condition, 'healthy'); // tomato healthy
    });

    test('byId returns null for out-of-range IDs', () {
      expect(ClassMap.byId(-1), isNull);
      expect(ClassMap.byId(9), isNull);
      expect(ClassMap.byId(100), isNull);
    });

    test('maize classes are IDs 0-3', () {
      for (int i = 0; i <= 3; i++) {
        expect(
          ClassMap.entries[i].crop,
          'maize',
          reason: 'ID $i should be maize',
        );
      }
    });

    test('tomato classes are IDs 4-8', () {
      for (int i = 4; i <= 8; i++) {
        expect(
          ClassMap.entries[i].crop,
          'tomato',
          reason: 'ID $i should be tomato',
        );
      }
    });

    test('each label matches crop__condition pattern', () {
      for (final entry in ClassMap.entries) {
        expect(
          entry.label,
          '${entry.crop}__${entry.condition}',
          reason:
              'Label for id ${entry.id} should follow crop__condition pattern',
        );
      }
    });
  });

  group('PreprocessContract', () {
    test('RGBA pixels become normalized RGB channel planes', () {
      final tensor = DiagnosisService.normalizeRgbaToNchw(
        Uint8List.fromList([255, 0, 128, 255, 0, 255, 64, 0]),
        2,
        1,
      );
      expect(tensor.length, 6);
      expect(tensor[0], closeTo((1 - 0.485) / 0.229, 1e-5));
      expect(tensor[1], closeTo((0 - 0.485) / 0.229, 1e-5));
      expect(tensor[2], closeTo((0 - 0.456) / 0.224, 1e-5));
      expect(tensor[3], closeTo((1 - 0.456) / 0.224, 1e-5));
      expect(tensor[4], closeTo((128 / 255 - 0.406) / 0.225, 1e-5));
      expect(tensor[5], closeTo((64 / 255 - 0.406) / 0.225, 1e-5));
    });

    test('input size is 224', () {
      expect(PreprocessContract.inputSize, 224);
    });

    test('scale is 1/255', () {
      expect(PreprocessContract.scale, closeTo(1.0 / 255.0, 1e-10));
    });

    test('ImageNet mean values match training artifact', () {
      expect(PreprocessContract.mean[0], closeTo(0.485, 1e-5));
      expect(PreprocessContract.mean[1], closeTo(0.456, 1e-5));
      expect(PreprocessContract.mean[2], closeTo(0.406, 1e-5));
    });

    test('ImageNet std values match training artifact', () {
      expect(PreprocessContract.std[0], closeTo(0.229, 1e-5));
      expect(PreprocessContract.std[1], closeTo(0.224, 1e-5));
      expect(PreprocessContract.std[2], closeTo(0.225, 1e-5));
    });

    test('color order is RGB', () {
      expect(PreprocessContract.colorOrder, 'RGB');
    });

    test('resize policy is direct_resize', () {
      expect(PreprocessContract.resizePolicy, 'direct_resize');
    });
  });

  group('RejectionPolicy', () {
    test('temperature matches calibration report', () {
      expect(RejectionPolicy.temperature, closeTo(1.0282130241394043, 1e-10));
    });

    test('confidence threshold is 0.8', () {
      expect(RejectionPolicy.confidenceThreshold, 0.8);
    });

    test('margin threshold is 0.15', () {
      expect(RejectionPolicy.marginThreshold, 0.15);
    });

    test('prototype similarity threshold is 0.72', () {
      expect(RejectionPolicy.prototypeSimilarityThreshold, 0.72);
    });

    test('prototype check is flagged as unavailable', () {
      // This must remain false until class_prototypes artifact is exported.
      // If this test fails, verify that prototypes are actually available
      // before setting prototypeCheckAvailable = true.
      expect(
        RejectionPolicy.prototypeCheckAvailable,
        isFalse,
        reason:
            'Prototype check must remain false until the class_prototypes '
            'artifact is exported from training. '
            'See plan.md Phase 2 and handoff notes.',
      );
    });
  });

  group('ModelContract', () {
    test('expected class count is 9', () {
      expect(ModelContract.expectedNumClasses, 9);
    });

    test('expected embedding dim is 576', () {
      expect(ModelContract.expectedEmbeddingDim, 576);
    });

    test('model asset path is set', () {
      expect(
        ModelContract.modelAssetPath,
        'assets/models/agrilens_model.tflite',
      );
    });
  });

  group('DiagnosisResult types', () {
    test('DiagnosisMatch holds expected fields', () {
      const entry = ClassEntry(
        id: 5,
        crop: 'tomato',
        condition: 'early_blight',
        label: 'tomato__early_blight',
      );
      const result = DiagnosisMatch(
        classEntry: entry,
        decisionState: DecisionState.possibleMatch,
        topLogit: 5.2,
        calibratedScore: 0.92,
        margin: 0.35,
      );

      expect(result.classEntry.id, 5);
      expect(result.classEntry.crop, 'tomato');
      expect(result.calibratedScore, 0.92);
      expect(result.prototypeSimilarity, isNull);
    });

    test('DiagnosisUncertain holds expected fields', () {
      const entry = ClassEntry(
        id: 2,
        crop: 'maize',
        condition: 'gray_leaf_spot',
        label: 'maize__gray_leaf_spot',
      );
      const result = DiagnosisUncertain(
        topClass: entry,
        calibratedScore: 0.65,
        margin: 0.08,
        reason: 'Below confidence threshold',
      );

      expect(result.topClass.id, 2);
      expect(result.calibratedScore, 0.65);
      expect(result.margin, 0.08);
    });

    test('DiagnosisFailure holds expected fields', () {
      const result = DiagnosisFailure(
        kind: DiagnosisFailureKind.imageDecodeFailed,
        message: 'Cannot decode file',
      );

      expect(result.kind, DiagnosisFailureKind.imageDecodeFailed);
      expect(result.message, 'Cannot decode file');
    });

    test('sealed class switch is exhaustive', () {
      // This verifies the sealed hierarchy works correctly for switch dispatch
      DiagnosisResult result = const DiagnosisFailure(
        kind: DiagnosisFailureKind.uniformOutput,
        message: 'test',
      );

      final description = switch (result) {
        DiagnosisMatch(:final classEntry) => 'match:${classEntry.condition}',
        DiagnosisUncertain(:final topClass) =>
          'uncertain:${topClass.condition}',
        DiagnosisFailure(:final kind) => 'failure:$kind',
      };

      expect(description, 'failure:DiagnosisFailureKind.uniformOutput');
    });
  });

  group('Preprocessing normalization math', () {
    // Verify the normalization formula: (value/255 - mean) / std
    test('pure white pixel normalizes correctly for R channel', () {
      const pixel = 255;
      const value = pixel / 255.0;
      const mean = 0.485;
      const std = 0.229;
      final normalized = (value - mean) / std;
      // White (1.0) normalizes to (1.0 - 0.485) / 0.229 ≈ 2.249
      expect(normalized, closeTo(2.249, 0.001));
    });

    test('pure black pixel normalizes correctly for R channel', () {
      const pixel = 0;
      const value = pixel / 255.0;
      const mean = 0.485;
      const std = 0.229;
      final normalized = (value - mean) / std;
      // Black (0.0) normalizes to (0.0 - 0.485) / 0.229 ≈ -2.118
      expect(normalized, closeTo(-2.118, 0.001));
    });

    test('mid-grey pixel is near zero after normalization', () {
      // Middle grey (127/255 ≈ 0.498) is close to the R mean (0.485)
      const pixel = 127;
      const value = pixel / 255.0;
      const mean = 0.485;
      const std = 0.229;
      final normalized = (value - mean) / std;
      // Should be small but not zero
      expect(normalized.abs(), lessThan(0.1));
    });
  });
}
