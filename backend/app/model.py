from __future__ import annotations

import json
import os
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps, UnidentifiedImageError
from tflite_runtime.interpreter import Interpreter


REPO_ROOT = Path(__file__).resolve().parents[2]
MODEL_PATH = Path(
    os.getenv("AGRILENS_MODEL_PATH", str(REPO_ROOT / "assets/models/agrilens_model.tflite"))
)
ARTIFACTS_DIR = Path(
    os.getenv(
        "AGRILENS_ARTIFACTS_DIR",
        str(REPO_ROOT.parent / "agrilens-training/artifacts"),
    )
)


@dataclass(frozen=True)
class Prediction:
    class_id: int
    crop: str
    condition: str
    decision_state: str
    top_logit: float
    calibrated_score: float
    margin: float
    prototype_similarity: float | None
    model_version: str
    preprocess_version: str
    failure_reason: str | None = None


class ModelContractError(RuntimeError):
    pass


class DiagnosisModel:
    def __init__(self, model_path: Path = MODEL_PATH, artifacts_dir: Path = ARTIFACTS_DIR):
        if not model_path.is_file():
            raise ModelContractError(f"TFLite model not found: {model_path}")

        self.class_map = json.loads((artifacts_dir / "class_map.json").read_text())
        preprocess = json.loads((artifacts_dir / "preprocess_contract.json").read_text())
        rejection = json.loads((artifacts_dir / "rejection_policy.json").read_text())
        self.input_size = int(preprocess["input_size"])
        self.mean = np.asarray(preprocess["mean"], dtype=np.float32)
        self.std = np.asarray(preprocess["std"], dtype=np.float32)
        self.temperature = float(rejection["temperature"])
        self.confidence_threshold = float(rejection["confidence_threshold"])
        self.margin_threshold = float(rejection["margin_threshold"])
        self.model_version = "v1_mobilenetv3"
        self.preprocess_version = "v1_224_imagenet"

        if [item["id"] for item in self.class_map] != list(range(9)):
            raise ModelContractError("class_map.json must contain the exact ordered IDs 0 through 8")
        if self.input_size != 224 or len(self.class_map) != 9:
            raise ModelContractError("Unexpected AgriLens image or class contract")

        self.interpreter = Interpreter(model_path=str(model_path), num_threads=2)
        self.interpreter.allocate_tensors()
        inputs = self.interpreter.get_input_details()
        outputs = self.interpreter.get_output_details()
        if len(inputs) != 1 or inputs[0]["dtype"] != np.float32:
            raise ModelContractError("Expected one float32 model input tensor")
        self.input = inputs[0]
        self.logits_output = self._find_output(outputs, (1, 9), required=True)
        self.embedding_output = self._find_output(outputs, (1, 576), required=False)
        if self.logits_output["dtype"] != np.float32:
            raise ModelContractError("Expected float32 classifier logits")
        self.input_layout = self._input_layout(tuple(int(v) for v in self.input["shape"]))

    @staticmethod
    def _find_output(outputs: list[dict], expected_shape: tuple[int, ...], required: bool):
        matches = [item for item in outputs if tuple(int(v) for v in item["shape"]) == expected_shape]
        if len(matches) > 1 or (required and len(matches) != 1):
            raise ModelContractError(f"Expected unique output tensor shape {expected_shape}")
        return matches[0] if matches else None

    def _input_layout(self, shape: tuple[int, ...]) -> str:
        if shape == (1, 3, self.input_size, self.input_size):
            return "nchw"
        if shape == (1, self.input_size, self.input_size, 3):
            return "nhwc"
        raise ModelContractError(f"Unexpected model input shape: {shape}")

    def _preprocess(self, image_bytes: bytes) -> np.ndarray:
        try:
            with Image.open(io_bytes(image_bytes)) as source:
                image = ImageOps.exif_transpose(source).convert("RGB")
                image = image.resize((self.input_size, self.input_size), Image.Resampling.BILINEAR)
                pixels = np.asarray(image, dtype=np.float32) / 255.0
        except (UnidentifiedImageError, OSError, ValueError) as exc:
            raise ValueError("Could not decode the uploaded image") from exc
        pixels = (pixels - self.mean) / self.std
        if self.input_layout == "nchw":
            pixels = np.transpose(pixels, (2, 0, 1))
        return np.expand_dims(pixels, axis=0).astype(np.float32, copy=False)

    def predict(self, image_bytes: bytes) -> Prediction:
        tensor = self._preprocess(image_bytes)
        self.interpreter.set_tensor(self.input["index"], tensor)
        self.interpreter.invoke()
        logits = np.asarray(self.interpreter.get_tensor(self.logits_output["index"])[0], dtype=np.float64)

        if logits.shape != (9,) or not np.isfinite(logits).all():
            raise ModelContractError("Model returned invalid logits")
        if float(np.max(logits) - np.min(logits)) < 1e-5:
            raise ValueError("The image did not produce a supported leaf result. Try a clearer leaf photo.")

        probabilities = _softmax(logits / self.temperature)
        order = np.argsort(probabilities)
        top_id = int(order[-1])
        confidence = float(probabilities[top_id])
        margin = confidence - float(probabilities[order[-2]])
        state = "possible_match"
        reason = None
        if confidence < self.confidence_threshold:
            state = "uncertain"
            reason = "The top class confidence is below the calibrated threshold."
        elif margin < self.margin_threshold:
            state = "uncertain"
            reason = "The top two class scores are too close to distinguish reliably."

        entry = self.class_map[top_id]
        return Prediction(
            class_id=top_id,
            crop=entry["crop"],
            condition=entry["condition"],
            decision_state=state,
            top_logit=float(logits[top_id]),
            calibrated_score=confidence,
            margin=margin,
            prototype_similarity=None,
            model_version=self.model_version,
            preprocess_version=self.preprocess_version,
            failure_reason=reason,
        )


def io_bytes(data: bytes):
    import io

    return io.BytesIO(data)


def _softmax(values: np.ndarray) -> np.ndarray:
    shifted = values - np.max(values)
    exponentials = np.exp(shifted)
    return exponentials / exponentials.sum()


@lru_cache(maxsize=1)
def get_diagnosis_model() -> DiagnosisModel:
    return DiagnosisModel()
