from __future__ import annotations

import os
import asyncio
from contextlib import asynccontextmanager
from datetime import date
from typing import Literal
from urllib.parse import quote
from uuid import UUID
import logging

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, File, Form, Header, HTTPException, Request, UploadFile
from pydantic import BaseModel, Field, model_validator
from redis.asyncio import Redis

from .ai_context import load_answer_context
from .auth import require_user, router as auth_router
from .conversations import conversation_answer_context, router as conversations_router, save_answer_messages, save_diagnosis
from .gemini import GeneratedAnswer, GeminiUnavailable, generate_answer
from .guidance import router as guidance_router
from .model import ModelContractError, Prediction, get_diagnosis_model
from .shop import router as shop_router
from .weather import WeatherResponse, router as weather_router, weather_for_coordinates

logger = logging.getLogger(__name__)

load_dotenv()


@asynccontextmanager
async def lifespan(application: FastAPI):
    redis_url = os.getenv("REDIS_URL", "").strip()
    application.state.weather_redis = Redis.from_url(redis_url) if redis_url else None
    try:
        yield
    finally:
        redis_client = application.state.weather_redis
        if redis_client is not None:
            await redis_client.aclose()


app = FastAPI(title="AgriLens API", version="1.0.0", lifespan=lifespan)
app.include_router(auth_router)
app.include_router(conversations_router)
app.include_router(shop_router)
app.include_router(weather_router)
app.include_router(guidance_router)


class PredictionResponse(BaseModel):
    class_id: int = Field(ge=0)
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


class AnswerRequest(BaseModel):
    conversation_id: UUID
    user_follow_up: str | None = Field(default=None, max_length=4000)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)

    @model_validator(mode="after")
    def require_coordinate_pair(self) -> AnswerRequest:
        if (self.latitude is None) != (self.longitude is None):
            raise ValueError("latitude and longitude must be supplied together")
        return self


class ProductSuggestion(BaseModel):
    id: UUID
    sku: str
    name: str
    description: str
    price: str
    currency: str
    stock_quantity: int
    crops: list[str]
    conditions: list[str]
    recommended_uses: list[str]
    evidence_source_url: str
    evidence_reviewed_at: date
    stock_verified_at: date
    image_url: str | None = None


class GuidanceCitation(BaseModel):
    id: UUID
    title: str
    organization: str
    url: str
    published_on: date | None = None
    reviewed_on: date


class AnswerResponse(BaseModel):
    answer: str
    products: list[ProductSuggestion] = Field(default_factory=list)
    sources: list[GuidanceCitation] = Field(default_factory=list)


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/v1/diagnoses", response_model=PredictionResponse)
async def diagnose(
    image: UploadFile = File(...),
    conversation_id: UUID = Form(...),
    user_id: str = Depends(require_user),
    authorization: str | None = Header(default=None),
):
    bearer_token = authorization.split(" ", 1)[1].strip() if authorization and authorization.lower().startswith("bearer ") else ""
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
        logger.exception("Diagnosis model contract error; conversation_id=%s", conversation_id)
        raise HTTPException(status_code=503, detail="The diagnosis model is unavailable") from exc
    response = PredictionResponse(**prediction.__dict__)
    await save_diagnosis(conversation_id=conversation_id, user_id=user_id, token=bearer_token,
                         image=payload, mime_type=image.content_type or "image/jpeg",
                         prediction=response.model_dump(mode="json"))
    return response


@app.post("/v1/answers", response_model=AnswerResponse)
async def answer(
    http_request: Request,
    request: AnswerRequest,
    user_id: str = Depends(require_user),
    authorization: str | None = Header(default=None),
):
    bearer_token = (
        authorization.split(" ", 1)[1].strip()
        if authorization and authorization.lower().startswith("bearer ")
        else ""
    )
    prediction, prior_messages = await conversation_answer_context(
        conversation_id=request.conversation_id, token=bearer_token,
    )

    context_task = load_answer_context(
        bearer_token=bearer_token,
        prediction=prediction,
        prior_messages=prior_messages,
        user_follow_up=request.user_follow_up,
    )
    weather_task = None
    if request.latitude is not None and request.longitude is not None:
        weather_task = weather_for_coordinates(
            request.latitude,
            request.longitude,
            getattr(http_request.app.state, "weather_redis", None),
        )
    if weather_task is not None:
        context, weather_result = await asyncio.gather(
            context_task, weather_task, return_exceptions=True
        )
        if isinstance(context, BaseException) and not isinstance(context, Exception):
            raise context
        if isinstance(weather_result, BaseException) and not isinstance(weather_result, Exception):
            raise weather_result
        if isinstance(context, Exception):
            logger.warning("AI context lookup failed: %s", context)
            context = {"products": [], "guidance": []}
        if isinstance(weather_result, WeatherResponse):
            weather_data = weather_result.model_dump(mode="json")
        else:
            if isinstance(weather_result, Exception):
                logger.warning("Weather context lookup failed")
            weather_data = None
    else:
        context = await context_task
        weather_data = None

    product_candidates = context.get("products", []) if prediction is not None else []
    guidance_candidates = context.get("guidance", [])
    try:
        generated: GeneratedAnswer = await generate_answer(
            prediction=prediction,
            prior_messages=prior_messages,
            user_follow_up=request.user_follow_up,
            weather=weather_data,
            guidance=guidance_candidates,
            products=product_candidates,
        )
    except GeminiUnavailable as exc:
        await save_answer_messages(conversation_id=request.conversation_id, user_id=user_id,
                                   token=bearer_token, follow_up=request.user_follow_up, failure=str(exc))
        raise HTTPException(status_code=503, detail=str(exc),
                            headers={"X-AgriLens-Followup-Saved": "true"}) from exc

    # Only hydrate identifiers from this request's verified search results.
    products_by_id = {str(item.get("id")): item for item in product_candidates}
    guidance_by_id = {str(item.get("id")): item for item in guidance_candidates}
    selected_products: list[ProductSuggestion] = []
    if prediction is not None and prediction["decision_state"] == "possible_match":
        for product_id in dict.fromkeys(generated.product_ids):
            product = products_by_id.get(product_id)
            if product is None:
                continue
            base = os.getenv("SUPABASE_URL", "").rstrip("/")
            image_path = product.get("image_path")
            image_url = (
                f"{base}/storage/v1/object/public/agrilens-products/{quote(str(image_path), safe='/')}"
                if base and image_path else None
            )
            selected_products.append(ProductSuggestion(
                id=product["id"], sku=product["sku"], name=product["name"],
                description=product.get("description", ""), price=str(product["price"]),
                currency=product["currency"], stock_quantity=product["stock_quantity"],
                crops=product.get("crops") or [], conditions=product.get("conditions") or [],
                recommended_uses=product.get("recommended_uses") or [],
                evidence_source_url=product["evidence_source_url"],
                evidence_reviewed_at=product["evidence_reviewed_at"],
                stock_verified_at=product["stock_verified_at"], image_url=image_url,
            ))

    selected_sources: list[GuidanceCitation] = []
    for source_id in dict.fromkeys(generated.source_ids):
        source = guidance_by_id.get(source_id)
        if source is not None:
            selected_sources.append(GuidanceCitation(
                id=source["id"], title=source["source_title"],
                organization=source["source_organization"], url=source["source_url"],
                published_on=source.get("source_published_on"), reviewed_on=source["reviewed_on"],
            ))
    response = AnswerResponse(
        answer=generated.answer.strip(), products=selected_products, sources=selected_sources
    )
    await save_answer_messages(conversation_id=request.conversation_id, user_id=user_id,
                               token=bearer_token, follow_up=request.user_follow_up,
                               answer=response.answer, metadata=response.model_dump(mode="json"))
    return response
