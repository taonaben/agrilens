from __future__ import annotations

import os
from datetime import date
from typing import Any
from urllib.parse import urlsplit

import httpx
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, field_validator

from .embeddings import EmbeddingUnavailable, embed_texts
from .shop import _admin_rest_headers, _admin_token

router = APIRouter(prefix="/v1/guidance", tags=["agronomy guidance"])


class GuidanceChunkInput(BaseModel):
    topic: str = Field(min_length=2, max_length=120)
    crop: str = Field(min_length=2, max_length=40)
    condition: str | None = Field(default=None, max_length=100)
    content: str = Field(min_length=20, max_length=4000)


class GuidanceSourceImport(BaseModel):
    title: str = Field(min_length=3, max_length=240)
    organization: str = Field(min_length=2, max_length=200)
    source_url: str = Field(min_length=10, max_length=2048)
    published_on: date | None = None
    reviewed_on: date
    chunks: list[GuidanceChunkInput] = Field(min_length=1, max_length=200)

    @field_validator("source_url")
    @classmethod
    def require_https_source(cls, value: str) -> str:
        value = value.strip()
        parsed = urlsplit(value)
        if parsed.scheme.lower() != "https" or not parsed.hostname or parsed.username or parsed.password:
            raise ValueError("Agronomy source URL must use HTTPS")
        return value


def _vector(values: list[float]) -> str:
    return "[" + ",".join(repr(value) for value in values) + "]"


@router.post("/import")
async def import_guidance_source(
    request: GuidanceSourceImport,
    _: None = Depends(_admin_token),
) -> dict[str, Any]:
    base_url = os.getenv("SUPABASE_URL", "").rstrip("/")
    if not base_url:
        raise HTTPException(503, "Agronomy guidance storage is not configured")
    searchable_texts = [
        "Agronomy guidance. "
        f"Source: {request.title}. Organization: {request.organization}. "
        f"Topic: {chunk.topic}. Crop: {chunk.crop}. "
        f"Condition: {chunk.condition or 'general crop management'}. {chunk.content}"
        for chunk in request.chunks
    ]
    try:
        embeddings = await embed_texts(searchable_texts)
    except (EmbeddingUnavailable, ValueError) as exc:
        raise HTTPException(503, "Could not index agronomy guidance") from exc

    rows = [
        {
            "source_url": request.source_url,
            "chunk_index": index,
            "source_title": request.title,
            "source_organization": request.organization,
            "source_published_on": request.published_on.isoformat() if request.published_on else None,
            "reviewed_on": request.reviewed_on.isoformat(),
            "topic": chunk.topic.strip(),
            "crop": chunk.crop.strip().lower(),
            "condition": chunk.condition.strip().lower() if chunk.condition else None,
            "content": chunk.content.strip(),
            "is_approved": True,
            "embedding": _vector(embeddings[index]),
            "embedding_model": os.getenv("GEMINI_EMBEDDING_MODEL", "gemini-embedding-2"),
        }
        for index, chunk in enumerate(request.chunks)
    ]
    headers = _admin_rest_headers("resolution=merge-duplicates,return=representation")
    try:
        async with httpx.AsyncClient(timeout=30) as client:
            response = await client.post(
                f"{base_url}/rest/v1/agrilens_guidance_chunks",
                params={"on_conflict": "source_url,chunk_index"},
                headers=headers,
                json=rows,
            )
            if response.is_error:
                raise HTTPException(502, "Could not save agronomy guidance")
            cleanup_response = await client.delete(
                f"{base_url}/rest/v1/agrilens_guidance_chunks",
                params={
                    "source_url": f"eq.{request.source_url}",
                    "chunk_index": f"gte.{len(rows)}",
                },
                headers=headers,
            )
            if cleanup_response.is_error:
                raise HTTPException(502, "Guidance was saved but obsolete chunks could not be removed; retry the import")
    except HTTPException:
        raise
    except httpx.HTTPError as exc:
        raise HTTPException(503, "Could not reach agronomy guidance storage") from exc
    return {"source_url": request.source_url, "chunks_indexed": len(rows)}
