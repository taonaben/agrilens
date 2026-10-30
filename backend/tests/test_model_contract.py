import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import numpy as np

from app.main import PredictionResponse
from app.model import DiagnosisModel
from app.shop import PredictionSync


class _FakeInterpreter:
    def __init__(self, model_path, num_threads):
        self.model_path = model_path

    def allocate_tensors(self):
        pass

    def get_input_details(self):
        return [{"index": 0, "dtype": np.float32, "shape": np.array([1, 224, 224, 3])}]

    def get_output_details(self):
        return [
            {"index": 0, "dtype": np.float32, "shape": np.array([1, 34])},
            {"index": 1, "dtype": np.float32, "shape": np.array([1, 576])},
        ]


class DynamicClassContractTests(unittest.TestCase):
    def test_model_accepts_logits_sized_from_the_ordered_map(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            model_path = root / "model.tflite"
            model_path.touch()
            classes = [
                {"id": i, "crop": "tomato", "condition": f"condition_{i}"}
                for i in range(34)
            ]
            (root / "class_map.json").write_text(json.dumps(classes))
            (root / "preprocess_contract.json").write_text(json.dumps({
                "input_size": 224,
                "mean": [0.485, 0.456, 0.406],
                "std": [0.229, 0.224, 0.225],
            }))
            (root / "rejection_policy.json").write_text(json.dumps({
                "temperature": 1.0,
                "confidence_threshold": 0.8,
                "margin_threshold": 0.15,
            }))
            with patch("app.model.Interpreter", _FakeInterpreter):
                model = DiagnosisModel(model_path, root)
            self.assertEqual(model.num_classes, 34)
            self.assertEqual(tuple(model.logits_output["shape"]), (1, 34))

    def test_api_and_history_contract_accept_new_ids_and_legacy_ids(self):
        shared = {
            "crop": "tomato",
            "condition": "thrips",
            "decision_state": "possible_match",
            "top_logit": 4.2,
            "calibrated_score": 0.91,
            "margin": 0.42,
            "model_version": "v2_34class_mobilenetv3",
            "preprocess_version": "v1_224_imagenet",
        }
        self.assertEqual(PredictionResponse(class_id=33, **shared).class_id, 33)
        sync = PredictionSync(
            id="5fae6748-9750-4dc7-8460-98dc6b8fc6f1",
            message_id="38a5684d-f96a-4e15-8304-38c0e92e9d44",
            decision_state="possibleMatch",
            created_at="2026-10-27T10:00:00Z",
            class_id=33,
            **{k: v for k, v in shared.items() if k != "decision_state"},
        )
        self.assertEqual(sync.class_id, 33)
        legacy = dict(shared, condition="healthy", model_version="v1_mobilenetv3")
        self.assertEqual(PredictionResponse(class_id=8, **legacy).class_id, 8)


if __name__ == "__main__":
    unittest.main()
