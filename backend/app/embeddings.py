from __future__ import annotations

import asyncio
import os

from google import genai
from google.genai import errors, types


EMBEDDING_DIMENSIONS = 768
EMBEDDING_PREFIX = (
    "Represent this content for semantic retrieval in a "
    "farming advice and verified product catalog:\n"
)


class EmbeddingUnavailable(RuntimeError):
    pass


def _client() -> genai.Client:
    api_key = os.getenv("GEMINI_API_KEY", "").strip()
    if not api_key:
        raise EmbeddingUnavailable("Gemini is not configured on the server")
    return genai.Client(
        api_key=api_key,
        http_options=types.HttpOptions(
            timeout=30_000,
            retry_options=types.HttpRetryOptions(attempts=1),
        ),
    )


async def _embed_batch(async_client: object, texts: list[str]) -> list[list[float]]:
    contents = [
        types.Content(role="user", parts=[types.Part(text=EMBEDDING_PREFIX + text)])
        for text in texts
    ]
    model = os.getenv("GEMINI_EMBEDDING_MODEL", "gemini-embedding-2")
    try:
        result = await asyncio.wait_for(
            async_client.models.embed_content(
                model=model,
                contents=contents,
                config=types.EmbedContentConfig(output_dimensionality=EMBEDDING_DIMENSIONS),
            ),
            timeout=35,
        )
    except errors.APIError as exc:
        raise EmbeddingUnavailable(f"Gemini embedding request failed (HTTP {exc.code})") from exc
    except (TimeoutError, asyncio.TimeoutError) as exc:
        raise EmbeddingUnavailable("Gemini embedding request timed out") from exc
    if len(result.embeddings or []) != len(texts):
        raise EmbeddingUnavailable("Gemini returned an unexpected number of embeddings")
    vectors: list[list[float]] = []
    for embedding in result.embeddings:
        if not embedding.values or len(embedding.values) != EMBEDDING_DIMENSIONS:
            raise EmbeddingUnavailable("Gemini returned an embedding with an unexpected size")
        vectors.append([float(value) for value in embedding.values])
    return vectors


async def embed_text(text: str) -> list[float]:
    if not text.strip():
        raise ValueError("Text to embed cannot be empty")
    async with _client().aio as async_client:
        return (await _embed_batch(async_client, [text]))[0]


async def embed_texts(texts: list[str], *, batch_size: int = 16) -> list[list[float]]:
    if any(not text.strip() for text in texts):
        raise ValueError("Texts to embed cannot be empty")
    if not texts:
        return []
    results: list[list[float]] = []
    async with _client().aio as async_client:
        for offset in range(0, len(texts), batch_size):
            results.extend(await _embed_batch(async_client, texts[offset:offset + batch_size]))
    return results
