from __future__ import annotations

import os
from typing import Literal

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, File, HTTPException, UploadFile
from pydantic import BaseModel, Field

from .auth import require_user, router as auth_router
from .gemini import GeminiUnavailable, generate_answer
from .model import ModelContractError, Prediction, get_diagnosis_model


load_dotenv()
app = FastAPI(title="AgriLens API", version="1.0.0")
app.include_router(auth_router)


class PredictionResponse(BaseModel):
    class_id: int = Field(ge=0, le=8)
    crop: Literal["maize", "tomato"]
    condition: str
    decision_state: Literal["possible_match", "uncertain", "unsupported_or_unclear"]
    top_logit: float
    calibrated_score: float = Field(ge=0, le=1)
    margin: float = Field(ge=0, le=1)
    prototype_similarity: float | None = None
    model_version: str
    preprocess_version: str
    failure_reason: str | None = None


class Message(BaseModel):
    role: Literal["user", "assistant"]
    content: str = Field(max_length=4000)


class AnswerRequest(BaseModel):
    prediction: PredictionResponse
    prior_messages: list[Message] = Field(default_factory=list, max_length=20)
    user_follow_up: str | None = Field(default=None, max_length=4000)


class AnswerResponse(BaseModel):
    answer: str


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/v1/diagnoses", response_model=PredictionResponse)
async def diagnose(
    image: UploadFile = File(...),
    user_id: str = Depends(require_user),
):
    del user_id  # Authenticated request; image bytes are processed in memory only.
    maximum = int(os.getenv("MAX_UPLOAD_BYTES", "10485760"))
    if image.content_type not in {
        "image/jpeg",
        "image/png",
        "image/webp",
        "application/octet-stream",
    }:
        raise HTTPException(status_code=415, detail="Upload a JPEG, PNG, or WebP image")
    payload = await image.read(maximum + 1)
    if len(payload) > maximum:
        raise HTTPException(status_code=413, detail="The selected image is too large")
    if not payload:
        raise HTTPException(status_code=400, detail="The selected image is empty")

    try:
        prediction: Prediction = get_diagnosis_model().predict(payload)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except ModelContractError as exc:
        raise HTTPException(status_code=503, detail="The diagnosis model is unavailable") from exc
    return PredictionResponse(**prediction.__dict__)


@app.post("/v1/answers", response_model=AnswerResponse)
async def answer(
    request: AnswerRequest,
    user_id: str = Depends(require_user),
):
    del user_id
    try:
        text = await generate_answer(
            prediction=request.prediction.model_dump(),
            prior_messages=[item.model_dump() for item in request.prior_messages],
            user_follow_up=request.user_follow_up,
        )
    except GeminiUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    return AnswerResponse(answer=text)
