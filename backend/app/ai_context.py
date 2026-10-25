from __future__ import annotations

import asyncio
import logging
import os
from typing import Any

import httpx

from .embeddings import EMBEDDING_DIMENSIONS, embed_text

logger = logging.getLogger(__name__)


class ContextUnavailable(RuntimeError):
    pass


def _vector_literal(values: list[float]) -> str:
    if len(values) != EMBEDDING_DIMENSIONS:
        raise ValueError("Embedding dimensions do not match the database index")
    return "[" + ",".join(repr(value) for value in values) + "]"


async def _rpc(
    name: str, *, bearer_token: str, embedding: str, embedding_model: str, count: int
) -> list[dict[str, Any]]:
    base_url = os.getenv("SUPABASE_URL", "").rstrip("/")
    anon_key = os.getenv("SUPABASE_ANON_KEY", "")
    if not base_url or not anon_key:
        raise ContextUnavailable("Supabase is not configured")
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(12, connect=4)) as client:
            response = await client.post(
                f"{base_url}/rest/v1/rpc/{name}",
                headers={"apikey": anon_key, "Authorization": f"Bearer {bearer_token}"},
                json={
                    "query_embedding": embedding,
                    "model_name": embedding_model,
                    "match_count": count,
                },
            )
    except httpx.HTTPError as exc:
        raise ContextUnavailable("Could not reach context storage") from exc
    if response.is_error:
        logger.warning("Context search RPC %s failed with status %s", name, response.status_code)
        raise ContextUnavailable("Context search is unavailable")
    try:
        rows = response.json()
    except ValueError as exc:
        raise ContextUnavailable("Context search returned invalid data") from exc
    if not isinstance(rows, list):
        raise ContextUnavailable("Context search returned invalid data")
    return [row for row in rows if isinstance(row, dict)]


async def load_answer_context(
    *,
    bearer_token: str,
    prediction: dict[str, Any],
    prior_messages: list[dict[str, str]],
    user_follow_up: str | None,
) -> dict[str, list[dict[str, Any]]]:
    recent = "\n".join(
        f"{message.get('role', '')}: {message.get('content', '')[:500]}"
        for message in prior_messages[-4:]
    )
    query = "\n".join(
        part for part in (
            f"Crop: {prediction.get('crop', '')}; classifier condition: {prediction.get('condition', '')}; "
            f"decision state: {prediction.get('decision_state', '')}",
            f"Farmer question: {(user_follow_up or '').strip()[:1000]}",
            f"Recent context: {recent}",
        ) if part.strip()
    )
    try:
        embedding = _vector_literal(await embed_text(query))
    except Exception as exc:
        logger.warning("AI context embedding failed: %s", exc)
        return {"products": [], "guidance": []}

    product_result, guidance_result = await asyncio.gather(
        _rpc(
            "search_verified_products", bearer_token=bearer_token, embedding=embedding,
            embedding_model=os.getenv("GEMINI_EMBEDDING_MODEL", "gemini-embedding-2"), count=8,
        ),
        _rpc(
            "search_reviewed_guidance", bearer_token=bearer_token, embedding=embedding,
            embedding_model=os.getenv("GEMINI_EMBEDDING_MODEL", "gemini-embedding-2"), count=8,
        ),
        return_exceptions=True,
    )
    if isinstance(product_result, asyncio.CancelledError):
        raise product_result
    if isinstance(product_result, Exception):
        logger.warning("Product context retrieval failed: %s", product_result)
        products = []
    else:
        products = product_result
    if isinstance(guidance_result, asyncio.CancelledError):
        raise guidance_result
    if isinstance(guidance_result, Exception):
        logger.warning("Agronomy guidance retrieval failed: %s", guidance_result)
        guidance = []
    else:
        guidance = guidance_result
    return {"products": products, "guidance": guidance}
