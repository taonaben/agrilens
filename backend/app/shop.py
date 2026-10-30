from __future__ import annotations

import asyncio
import csv
import hmac
import ipaddress
import io
import json
import logging
import math
import os
import re
import socket
from datetime import date, datetime
from decimal import Decimal, InvalidOperation
from typing import Any
from urllib.parse import quote, urljoin, urlsplit
from uuid import UUID, uuid4

import httpx
from fastapi import APIRouter, Depends, File, Header, HTTPException, UploadFile
from pydantic import BaseModel, Field, field_validator, model_validator

from .auth import require_user
from .embeddings import EMBEDDING_DIMENSIONS, EmbeddingUnavailable, embed_text, embed_texts

router = APIRouter(prefix="/v1", tags=["shop"])
logger = logging.getLogger(__name__)


def _supabase() -> tuple[str, str]:
    url = os.getenv("SUPABASE_URL", "").rstrip("/")
    key = os.getenv("SUPABASE_ANON_KEY", "")
    if not url or not key:
        raise HTTPException(503, "Shop storage is not configured")
    return url, key


def _headers(user_token: str) -> dict[str, str]:
    _, key = _supabase()
    return {"apikey": key, "Authorization": f"Bearer {user_token}"}


async def _rest(path: str, *, user_token: str, method: str = "GET", json: Any = None,
                params: dict[str, str] | None = None, headers: dict[str, str] | None = None) -> Any:
    url, _ = _supabase()
    request_headers = _headers(user_token)
    request_headers.update(headers or {})
    try:
        async with httpx.AsyncClient(timeout=15) as client:
            response = await client.request(method, f"{url}/rest/v1/{path}",
                                            headers=request_headers, json=json, params=params)
    except httpx.HTTPError as exc:
        raise HTTPException(503, "Could not reach shop storage") from exc
    if response.is_error:
        if path.startswith("rpc/create_shop_order") and response.status_code in (400, 409):
            raise HTTPException(409, "Order could not be placed because a product is unavailable or stock changed")
        raise HTTPException(502, "Shop storage request failed")
    if not response.content:
        return None
    try:
        return response.json()
    except ValueError as exc:
        raise HTTPException(502, "Shop storage returned an invalid response") from exc


def _admin_token(x_shop_admin_token: str | None = Header(default=None)) -> None:
    expected = os.getenv("SHOP_ADMIN_TOKEN", "")
    if not expected:
        raise HTTPException(503, "Shop catalog management is not configured")
    if not x_shop_admin_token or not hmac.compare_digest(x_shop_admin_token, expected):
        raise HTTPException(403, "Catalog management is restricted")


def _admin_rest_headers(prefer: str = "") -> dict[str, str]:
    key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
    if not key:
        raise HTTPException(503, "Shop catalog management is not configured")
    result = {"apikey": key, "Authorization": f"Bearer {key}", "Content-Type": "application/json"}
    if prefer:
        result["Prefer"] = prefer
    return result


def _storage_headers(mime_type: str, *, upsert: bool = False) -> dict[str, str]:
    key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
    if not key:
        raise HTTPException(503, "Shop catalog management is not configured")
    headers = {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Content-Type": mime_type,
        "x-upsert": "true" if upsert else "false",
    }
    return headers


def _public_product_image_url(path: str | None) -> str | None:
    if not path:
        return None
    base = os.getenv("SUPABASE_URL", "").rstrip("/")
    if not base:
        return None
    return f"{base}/storage/v1/object/public/agrilens-products/{quote(path, safe='/')}"


def _product_response(row: dict[str, Any]) -> dict[str, Any]:
    result = dict(row)
    result.pop("search_embedding", None)
    result.pop("search_embedding_model", None)
    result["image_url"] = _public_product_image_url(result.pop("image_path", None))
    return result


def _parse_embedding(value: Any) -> list[float] | None:
    if isinstance(value, list):
        parsed = value
    elif isinstance(value, str):
        text = value.strip()
        if not text:
            return None
        try:
            loaded = json.loads(text)
        except ValueError:
            return None
        if not isinstance(loaded, list):
            return None
        parsed = loaded
    else:
        return None
    if len(parsed) != EMBEDDING_DIMENSIONS:
        return None
    try:
        vector = [float(item) for item in parsed]
    except (TypeError, ValueError):
        return None
    if not any(vector):
        return None
    return vector


def _cosine_similarity(left: list[float], right: list[float]) -> float:
    dot = 0.0
    left_norm_sq = 0.0
    right_norm_sq = 0.0
    for left_value, right_value in zip(left, right):
        dot += left_value * right_value
        left_norm_sq += left_value * left_value
        right_norm_sq += right_value * right_value
    if left_norm_sq <= 0 or right_norm_sq <= 0:
        return -1.0
    return dot / math.sqrt(left_norm_sq * right_norm_sq)


def _personalization_profile(
    *,
    predictions: list[dict[str, Any]],
    orders: list[dict[str, Any]],
) -> str:
    lines: list[str] = []
    for prediction in predictions[:12]:
        crop = str(prediction.get("crop") or "").strip().lower()
        condition = str(prediction.get("condition") or "").strip().lower()
        decision_state = str(prediction.get("decision_state") or "").strip()
        if not (crop or condition):
            continue
        lines.append(
            "Scanned leaf context: "
            f"crop={crop or 'unknown'}, "
            f"condition={condition or 'unknown'}, "
            f"decision_state={decision_state or 'unknown'}"
        )
    for order in orders[:10]:
        for item in (order.get("shop_order_items") or [])[:12]:
            name = str(item.get("name_snapshot") or "").strip()
            sku = str(item.get("sku_snapshot") or "").strip()
            quantity = item.get("quantity")
            if not (name or sku):
                continue
            lines.append(
                "Previous order context: "
                f"product={name or sku}, sku={sku or 'unknown'}, quantity={quantity}"
            )
    return "\n".join(lines).strip()


async def _personalize_product_rows(
    *,
    rows: list[dict[str, Any]],
    token: str,
) -> list[dict[str, Any]]:
    if not rows:
        return rows
    prediction_rows, order_rows = await asyncio.gather(
        _rest("agrilens_predictions", user_token=token, params={
            "select": "crop,condition,decision_state,created_at",
            "order": "created_at.desc",
            "limit": "20",
        }),
        _rest("shop_orders", user_token=token, params={
            "select": "id,created_at,shop_order_items(name_snapshot,sku_snapshot,quantity)",
            "order": "created_at.desc",
            "limit": "10",
        }),
        return_exceptions=True,
    )
    if isinstance(prediction_rows, asyncio.CancelledError):
        raise prediction_rows
    if isinstance(order_rows, asyncio.CancelledError):
        raise order_rows
    predictions = prediction_rows if isinstance(prediction_rows, list) else []
    if isinstance(prediction_rows, Exception):
        logger.warning("Shop personalization skipped prediction context: %s", prediction_rows)
    orders = order_rows if isinstance(order_rows, list) else []
    if isinstance(order_rows, Exception):
        logger.warning("Shop personalization skipped order context: %s", order_rows)
    profile = _personalization_profile(
        predictions=[row for row in predictions if isinstance(row, dict)],
        orders=[row for row in orders if isinstance(row, dict)],
    )
    if not profile:
        return rows
    try:
        profile_embedding = await embed_text(profile)
    except (EmbeddingUnavailable, ValueError) as exc:
        logger.warning("Shop personalization embedding unavailable: %s", exc)
        return rows
    scored: list[tuple[int, float]] = []
    for index, row in enumerate(rows):
        embedding = _parse_embedding(row.get("search_embedding"))
        if embedding is None:
            continue
        scored.append((index, _cosine_similarity(profile_embedding, embedding)))
    if not scored:
        return rows
    scored.sort(key=lambda item: item[1], reverse=True)
    ranked_indexes = [index for index, _ in scored]
    ranked_index_set = set(ranked_indexes)
    ranked_indexes.extend(
        index for index in range(len(rows)) if index not in ranked_index_set
    )
    return [rows[index] for index in ranked_indexes]


async def _validate_public_image_url(value: str) -> None:
    try:
        parsed = urlsplit(value)
        if parsed.scheme.lower() != "https" or not parsed.hostname or parsed.username or parsed.password:
            raise ValueError
        if parsed.port not in (None, 443):
            raise ValueError
        loop = asyncio.get_running_loop()
        addresses = await loop.getaddrinfo(parsed.hostname, 443, type=socket.SOCK_STREAM)
        if not addresses or any(not ipaddress.ip_address(item[4][0]).is_global for item in addresses):
            raise ValueError
    except (ValueError, UnicodeError, socket.gaierror, OSError) as exc:
        raise HTTPException(400, "Image URL must resolve to a public HTTPS host") from exc


def _image_type(data: bytes) -> tuple[str, str]:
    if data.startswith(b"\xff\xd8\xff"):
        return "image/jpeg", "jpg"
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png", "png"
    if len(data) >= 12 and data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "image/webp", "webp"
    raise HTTPException(415, "Product image must be a JPEG, PNG, or WebP file")


async def _download_product_image(source_url: str) -> tuple[bytes, str, str]:
    maximum = int(os.getenv("MAX_PRODUCT_IMAGE_BYTES", str(5 * 1024 * 1024)))
    current_url = source_url
    try:
        async with httpx.AsyncClient(timeout=12, follow_redirects=False, trust_env=False) as client:
            for redirect_count in range(4):
                await _validate_public_image_url(current_url)
                async with client.stream("GET", current_url, headers={"Accept": "image/jpeg,image/png,image/webp"}) as response:
                    if response.status_code in (301, 302, 303, 307, 308):
                        location = response.headers.get("location")
                        if not location or redirect_count == 3:
                            raise HTTPException(400, "Image URL has too many redirects")
                        current_url = urljoin(current_url, location)
                        continue
                    if response.status_code != 200:
                        raise HTTPException(400, "Could not download product image")
                    content_length = response.headers.get("content-length")
                    if content_length and int(content_length) > maximum:
                        raise HTTPException(413, "Product image exceeds the size limit")
                    chunks = bytearray()
                    async for chunk in response.aiter_bytes():
                        chunks.extend(chunk)
                        if len(chunks) > maximum:
                            raise HTTPException(413, "Product image exceeds the size limit")
                    data = bytes(chunks)
                    mime_type, extension = _image_type(data)
                    return data, mime_type, extension
    except HTTPException:
        raise
    except (httpx.HTTPError, ValueError, OSError) as exc:
        raise HTTPException(400, "Could not download product image") from exc
    raise HTTPException(400, "Could not download product image")


async def _upload_product_image(data: bytes, mime_type: str, extension: str, sku: str) -> str:
    base = os.getenv("SUPABASE_URL", "").rstrip("/")
    if not base:
        raise HTTPException(503, "Shop storage is not configured")
    slug = re.sub(r"[^A-Za-z0-9_-]+", "-", sku).strip("-")[:60] or "product"
    path = f"{slug}/{uuid4().hex}.{extension}"
    try:
        async with httpx.AsyncClient(timeout=20) as client:
            response = await client.post(
                f"{base}/storage/v1/object/agrilens-products/{quote(path, safe='/')}",
                headers=_storage_headers(mime_type),
                content=data,
            )
    except httpx.HTTPError as exc:
        raise HTTPException(503, "Could not upload product image") from exc
    if response.is_error:
        raise HTTPException(502, "Could not upload product image to Supabase Storage")
    return path


async def _delete_product_images(paths: list[str]) -> None:
    if not paths:
        return
    base = os.getenv("SUPABASE_URL", "").rstrip("/")
    key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
    if not base or not key:
        return
    try:
        async with httpx.AsyncClient(timeout=15) as client:
            await client.delete(
                f"{base}/storage/v1/object/agrilens-products",
                headers={"apikey": key, "Authorization": f"Bearer {key}", "Content-Type": "application/json"},
                json={"prefixes": paths},
            )
    except httpx.HTTPError:
        pass


class ProductInput(BaseModel):
    sku: str = Field(min_length=1, max_length=80)
    name: str = Field(min_length=1, max_length=160)
    description: str = Field(default="", max_length=2000)
    price: Decimal = Field(gt=0, max_digits=12, decimal_places=2)
    currency: str = Field(min_length=3, max_length=3)
    stock_quantity: int = Field(ge=0, le=1_000_000)
    crops: list[str] = Field(default_factory=list, max_length=10)
    conditions: list[str] = Field(default_factory=list, max_length=30)
    recommended_uses: list[str] = Field(default_factory=list, max_length=20)
    evidence_source_url: str | None = Field(default=None, max_length=2048)
    evidence_reviewed_at: date | None = None
    stock_verified_at: date | None = None
    recommendation_eligible: bool = False
    image_url: str | None = Field(default=None, max_length=2048)

    @field_validator("sku", "name", "currency")
    @classmethod
    def trim_text(cls, value: str) -> str:
        return value.strip()

    @field_validator("currency")
    @classmethod
    def uppercase_currency(cls, value: str) -> str:
        value = value.upper()
        if not re.fullmatch(r"[A-Z]{3}", value):
            raise ValueError("currency must be a three-letter code")
        return value

    @field_validator("crops", "conditions", "recommended_uses")
    @classmethod
    def normalize_tags(cls, value: list[str]) -> list[str]:
        normalized = list(dict.fromkeys(item.strip().lower() for item in value if item.strip()))
        if any(len(item) > 80 for item in normalized):
            raise ValueError("tag is too long")
        return normalized

    @field_validator("evidence_source_url")
    @classmethod
    def require_https_evidence(cls, value: str | None) -> str | None:
        value = value.strip() if value else None
        if value:
            parsed = urlsplit(value)
            if parsed.scheme.lower() != "https" or not parsed.hostname or parsed.username or parsed.password:
                raise ValueError("Evidence source URL must use HTTPS")
        return value or None

    @model_validator(mode="after")
    def validate_recommendation_evidence(self) -> ProductInput:
        if self.recommendation_eligible and not all((
            self.crops,
            self.recommended_uses,
            self.evidence_source_url,
            self.evidence_reviewed_at,
            self.stock_verified_at,
        )):
            raise ValueError(
                "Eligible products need crop fit, approved uses, evidence source and review date, and stock verification date"
            )
        return self


def _product_search_text(payload: dict[str, Any]) -> str:
    return "\n".join((
        f"Product: {payload['name']}",
        f"Description: {payload.get('description', '')}",
        f"Supported crops: {', '.join(payload.get('crops') or [])}",
        f"Supported conditions: {', '.join(payload.get('conditions') or [])}",
        f"Reviewed uses: {', '.join(payload.get('recommended_uses') or [])}",
    ))


async def _attach_product_embeddings(payloads: list[dict[str, Any]]) -> None:
    eligible = [payload for payload in payloads if payload.get("recommendation_eligible")]
    try:
        vectors = await embed_texts([_product_search_text(payload) for payload in eligible])
    except (EmbeddingUnavailable, ValueError) as exc:
        raise HTTPException(503, "Could not index verified products") from exc
    model = os.getenv("GEMINI_EMBEDDING_MODEL", "gemini-embedding-2")
    vector_by_identity = {id(payload): vector for payload, vector in zip(eligible, vectors)}
    for payload in payloads:
        payload["search_embedding"] = vector_by_identity.get(id(payload))
        payload["search_embedding_model"] = model if payload.get("recommendation_eligible") else None

    @field_validator("image_url")
    @classmethod
    def trim_image_url(cls, value: str | None) -> str | None:
        value = value.strip() if value else None
        return value or None


class OrderItemInput(BaseModel):
    product_id: UUID
    quantity: int = Field(ge=1, le=1000)


class CreateOrderRequest(BaseModel):
    items: list[OrderItemInput] = Field(min_length=1, max_length=50)
    contact_name: str = Field(min_length=1, max_length=160)
    phone: str = Field(min_length=5, max_length=40)
    delivery_address: str = Field(min_length=5, max_length=1000)

    @field_validator("contact_name", "phone", "delivery_address")
    @classmethod
    def trim_order_fields(cls, value: str) -> str:
        return value.strip()

    @field_validator("items")
    @classmethod
    def unique_products(cls, value: list[OrderItemInput]) -> list[OrderItemInput]:
        if len({item.product_id for item in value}) != len(value):
            raise ValueError("Each product may appear only once")
        return value


class ConversationSync(BaseModel):
    id: UUID
    title: str = Field(max_length=300)
    created_at: datetime
    updated_at: datetime


class MessageSync(BaseModel):
    id: UUID
    conversation_id: UUID
    role: str = Field(pattern="^(user|assistant|system)$")
    content_type: str = Field(pattern="^(text|image)$")
    text_content: str | None = Field(default=None, max_length=4000)
    image_object_path: str | None = Field(default=None, max_length=1000)
    lifecycle: str = Field(pattern="^(pending|complete|failed)$")
    failure_reason: str | None = Field(default=None, max_length=1000)
    created_at: datetime
    updated_at: datetime


class PredictionSync(BaseModel):
    id: UUID
    message_id: UUID
    class_id: int = Field(ge=0)
    crop: str = Field(pattern="^(maize|tomato)$")
    condition: str = Field(min_length=1, max_length=100)
    decision_state: str = Field(pattern="^(possibleMatch|uncertain|unsupportedOrUnclear)$")
    top_logit: float
    calibrated_score: float = Field(ge=0, le=1)
    margin: float = Field(ge=0, le=1)
    prototype_similarity: float | None = None
    model_version: str = Field(min_length=1, max_length=100)
    preprocess_version: str = Field(min_length=1, max_length=100)
    failure_reason: str | None = Field(default=None, max_length=1000)
    created_at: datetime


class HistorySyncRequest(BaseModel):
    conversations: list[ConversationSync] = Field(default_factory=list, max_length=100)
    messages: list[MessageSync] = Field(default_factory=list, max_length=500)
    predictions: list[PredictionSync] = Field(default_factory=list, max_length=500)


class CropPreferences(BaseModel):
    crops: list[str] = Field(max_length=10)

    @field_validator("crops")
    @classmethod
    def supported_unique_crops(cls, value: list[str]) -> list[str]:
        crops = list(dict.fromkeys(crop.strip().lower() for crop in value))
        unsupported = set(crops) - {"maize", "tomato"}
        if unsupported:
            raise ValueError("Supported crops are maize and tomato")
        return crops


@router.post("/history/sync")
async def sync_history(request: HistorySyncRequest, user_id: str = Depends(require_user), authorization: str | None = Header(default=None)):
    token = _bearer_token(authorization)
    if request.conversations:
        rows = [item.model_dump(mode="json") | {"owner_id": user_id} for item in request.conversations]
        await _rest("agrilens_conversations?on_conflict=id", user_token=token, method="POST", json=rows,
                    headers={"Prefer": "resolution=merge-duplicates,return=minimal"})
    if request.messages:
        requested_ids = {str(item.conversation_id) for item in request.messages}
        owned = await _rest("agrilens_conversations", user_token=token,
                            params={"select": "id", "id": f"in.({','.join(sorted(requested_ids))})"})
        owned_ids = {row["id"] for row in (owned or [])}
        if not requested_ids.issubset(owned_ids):
            raise HTTPException(400, "Every synced message must belong to a saved conversation")
        rows = [item.model_dump(mode="json") | {"owner_id": user_id} for item in request.messages]
        await _rest("agrilens_messages?on_conflict=id", user_token=token, method="POST", json=rows,
                    headers={"Prefer": "resolution=merge-duplicates,return=minimal"})
    if request.predictions:
        message_ids = {str(item.message_id) for item in request.predictions}
        owned = await _rest("agrilens_messages", user_token=token,
                            params={"select": "id", "id": f"in.({','.join(sorted(message_ids))})"})
        owned_ids = {row["id"] for row in (owned or [])}
        if not message_ids.issubset(owned_ids):
            raise HTTPException(400, "Every synced prediction must belong to a saved message")
        rows = [item.model_dump(mode="json") | {"owner_id": user_id} for item in request.predictions]
        await _rest("agrilens_predictions?on_conflict=id", user_token=token, method="POST", json=rows,
                    headers={"Prefer": "resolution=merge-duplicates,return=minimal"})
    return {"synced": {"conversations": len(request.conversations), "messages": len(request.messages),
                        "predictions": len(request.predictions)}}


@router.get("/profile/crops")
async def get_crop_preferences(user_id: str = Depends(require_user), authorization: str | None = Header(default=None)):
    del user_id
    return await _rest("agrilens_user_crops", user_token=_bearer_token(authorization),
                       params={"select": "crop", "order": "crop.asc"})


@router.put("/profile/crops")
async def set_crop_preferences(request: CropPreferences, user_id: str = Depends(require_user), authorization: str | None = Header(default=None)):
    del user_id
    await _rest("rpc/set_agrilens_user_crops", user_token=_bearer_token(authorization), method="POST",
                json={"p_crops": request.crops})
    return {"crops": request.crops}


@router.get("/products")
async def list_products(user_id: str = Depends(require_user), authorization: str | None = Header(default=None)):
    del user_id
    token = _bearer_token(authorization)
    rows = await _rest("shop_products", user_token=token,
                       params={"select": "*", "active": "eq.true", "order": "name.asc"})
    personalized_rows = await _personalize_product_rows(
        rows=[row for row in rows or [] if isinstance(row, dict)],
        token=token,
    )
    return [_product_response(row) for row in personalized_rows]


def _bearer_token(authorization: str | None = Header(default=None)) -> str:
    # Used only as a helper by the dependency wrapper below.
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(401, "A signed-in user is required")
    return authorization.split(" ", 1)[1].strip()


@router.post("/products", dependencies=[Depends(_admin_token)], status_code=201)
async def add_product(product: ProductInput):
    image_path = None
    try:
        payload = product.model_dump(mode="json", exclude={"image_url"})
        await _attach_product_embeddings([payload])
        if product.image_url:
            data, mime_type, extension = await _download_product_image(product.image_url)
            image_path = await _upload_product_image(data, mime_type, extension, product.sku)
            payload["image_path"] = image_path
        async with httpx.AsyncClient(timeout=15) as client:
            url, _ = _supabase()
            response = await client.post(f"{url}/rest/v1/shop_products",
                headers=_admin_rest_headers("return=representation"), json=payload)
    except httpx.HTTPError as exc:
        await _delete_product_images([image_path] if image_path else [])
        raise HTTPException(503, "Could not reach shop storage") from exc
    except HTTPException:
        await _delete_product_images([image_path] if image_path else [])
        raise
    if response.status_code == 409:
        await _delete_product_images([image_path] if image_path else [])
        raise HTTPException(409, "A product with this SKU already exists")
    if response.is_error:
        await _delete_product_images([image_path] if image_path else [])
        raise HTTPException(502, "Could not add product")
    return _product_response(response.json()[0])


@router.delete("/products/{product_id}", dependencies=[Depends(_admin_token)], status_code=204)
async def remove_product(product_id: UUID):
    try:
        async with httpx.AsyncClient(timeout=15) as client:
            url, _ = _supabase()
            response = await client.patch(f"{url}/rest/v1/shop_products",
                headers=_admin_rest_headers("return=minimal"), params={"id": f"eq.{product_id}", "active": "eq.true"},
                json={"active": False})
    except httpx.HTTPError as exc:
        raise HTTPException(503, "Could not reach shop storage") from exc
    if response.is_error:
        raise HTTPException(502, "Could not remove product")
    return None


@router.post("/products/import", dependencies=[Depends(_admin_token)])
async def import_products(file: UploadFile = File(...)):
    if file.content_type not in {"text/csv", "application/csv", "application/vnd.ms-excel", "application/octet-stream"}:
        raise HTTPException(415, "Upload a CSV file")
    raw = await file.read(2_000_001)
    if len(raw) > 2_000_000:
        raise HTTPException(413, "CSV file exceeds 2 MB")
    try:
        text = raw.decode("utf-8-sig")
        reader = csv.DictReader(io.StringIO(text))
        required = {"sku", "name", "description", "price", "currency", "stock_quantity", "crops", "conditions"}
        optional = {
            "image_url", "recommended_uses", "evidence_source_url", "evidence_reviewed_at",
            "stock_verified_at", "recommendation_eligible",
        }
        allowed = required | optional
        if reader.fieldnames is None or not required.issubset(reader.fieldnames) or not set(reader.fieldnames).issubset(allowed):
            raise ValueError("CSV headers must include: " + ",".join(sorted(required)) + "; image_url is optional")
        has_image_column = "image_url" in reader.fieldnames
        records = []
        image_sources: dict[str, str | None] = {}
        for line_number, row in enumerate(reader, start=2):
            try:
                price = Decimal(row["price"])
                stock = int(row["stock_quantity"])
                eligibility = (row.get("recommendation_eligible") or "false").strip().lower()
                if eligibility not in {"true", "false"}:
                    raise ValueError("recommendation_eligible must be true or false")
                data = ProductInput(sku=row["sku"], name=row["name"], description=row["description"],
                    price=price, currency=row["currency"], stock_quantity=stock,
                    crops=[tag for tag in row["crops"].split("|") if tag.strip()],
                    conditions=[tag for tag in row["conditions"].split("|") if tag.strip()],
                    recommended_uses=[tag for tag in (row.get("recommended_uses") or "").split("|") if tag.strip()],
                    evidence_source_url=row.get("evidence_source_url") or None,
                    evidence_reviewed_at=date.fromisoformat(row["evidence_reviewed_at"]) if row.get("evidence_reviewed_at") else None,
                    stock_verified_at=date.fromisoformat(row["stock_verified_at"]) if row.get("stock_verified_at") else None,
                    recommendation_eligible=eligibility == "true",
                    image_url=row.get("image_url"))
            except (ValueError, InvalidOperation, TypeError) as exc:
                raise ValueError(f"Invalid product row {line_number}") from exc
            product_payload = data.model_dump(mode="json", exclude={"image_url"}) | {"active": True}
            records.append(product_payload)
            image_sources[data.sku] = data.image_url
        if not records:
            raise ValueError("CSV contains no product rows")
        if len(records) > 1000:
            raise ValueError("CSV may contain at most 1000 products")
        skus = [row["sku"] for row in records]
        if len(skus) != len(set(skus)):
            raise ValueError("CSV contains duplicate SKUs")
    except (UnicodeDecodeError, csv.Error, ValueError) as exc:
        raise HTTPException(400, str(exc)) from exc

    uploaded_paths: list[str] = []
    try:
        await _attach_product_embeddings(records)
        for record in records:
            source_url = image_sources[record["sku"]]
            if source_url:
                data, mime_type, extension = await _download_product_image(source_url)
                path = await _upload_product_image(data, mime_type, extension, record["sku"])
                uploaded_paths.append(path)
                record["image_path"] = path
            elif has_image_column:
                record["image_path"] = None
        async with httpx.AsyncClient(timeout=30) as client:
            url, _ = _supabase()
            response = await client.post(f"{url}/rest/v1/shop_products",
                headers=_admin_rest_headers("resolution=merge-duplicates,return=representation"),
                params={"on_conflict": "sku"}, json=records)
    except httpx.HTTPError as exc:
        await _delete_product_images(uploaded_paths)
        raise HTTPException(503, "Could not reach shop storage") from exc
    except HTTPException:
        await _delete_product_images(uploaded_paths)
        raise
    if response.is_error:
        await _delete_product_images(uploaded_paths)
        raise HTTPException(502, "Could not import products")
    return {"imported": len(response.json())}


@router.get("/recommendations", deprecated=True, include_in_schema=False)
async def recommendations_deprecated():
    raise HTTPException(
        status_code=410,
        detail="This rule-based endpoint is retired; answer-specific product suggestions are returned by POST /v1/answers.",
    )


@router.post("/orders", status_code=201)
async def create_order(request: CreateOrderRequest, user_id: str = Depends(require_user), authorization: str | None = Header(default=None)):
    del user_id
    token = authorization.split(" ", 1)[1].strip() if authorization and authorization.lower().startswith("bearer ") else ""
    payload = {"p_items": [item.model_dump(mode="json") for item in request.items],
              "p_contact_name": request.contact_name, "p_phone": request.phone,
              "p_delivery_address": request.delivery_address}
    response = await _rest("rpc/create_shop_order", user_token=token, method="POST", json=payload)
    order_id = response if isinstance(response, str) else response.get("id") if isinstance(response, dict) else None
    if not order_id:
        raise HTTPException(502, "Order storage returned an invalid response")
    rows = await _rest("shop_orders", user_token=token,
        params={"select": "*,shop_order_items(*)", "id": f"eq.{order_id}"})
    return rows[0] if rows else {"id": order_id}


@router.get("/orders")
async def get_orders(user_id: str = Depends(require_user), authorization: str | None = Header(default=None)):
    del user_id
    token = authorization.split(" ", 1)[1].strip() if authorization and authorization.lower().startswith("bearer ") else ""
    return await _rest("shop_orders", user_token=token,
        params={"select": "*,shop_order_items(*)", "order": "created_at.desc"})
