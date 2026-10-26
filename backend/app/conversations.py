from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone
from typing import Any
from urllib.parse import quote
from uuid import UUID, uuid4

import httpx
from fastapi import APIRouter, Depends, Header, HTTPException, Query
from fastapi.responses import Response
from pydantic import BaseModel, Field

from .auth import require_user

router = APIRouter(prefix="/v1/conversations", tags=["conversations"])


def _supabase() -> tuple[str, str]:
    url = os.getenv("SUPABASE_URL", "").rstrip("/")
    key = os.getenv("SUPABASE_ANON_KEY", "")
    if not url or not key:
        raise HTTPException(503, "Conversation storage is not configured")
    return url, key


async def _request(path: str, *, token: str, method: str = "GET", json: Any = None,
                   params: dict[str, str] | None = None, content: bytes | None = None,
                   content_type: str | None = None, prefer: str | None = None) -> Any:
    base, anon_key = _supabase()
    headers = {"apikey": anon_key, "Authorization": f"Bearer {token}"}
    if content_type:
        headers["Content-Type"] = content_type
    if prefer:
        headers["Prefer"] = prefer
    endpoint = f"{base}{path}"
    try:
        async with httpx.AsyncClient(timeout=30) as client:
            response = await client.request(method, endpoint, headers=headers, json=json,
                                            params=params, content=content)
    except httpx.HTTPError as exc:
        raise HTTPException(503, "Could not reach conversation storage") from exc
    if response.is_error:
        if response.status_code == 404:
            raise HTTPException(404, "Conversation not found")
        raise HTTPException(502, "Conversation storage request failed")
    if not response.content:
        return None
    if "application/json" in response.headers.get("content-type", ""):
        try:
            return response.json()
        except ValueError as exc:
            raise HTTPException(502, "Conversation storage returned invalid data") from exc
    return response


def _bearer(authorization: str | None) -> str:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(401, "A valid sign-in session is required")
    return authorization.split(" ", 1)[1].strip()


async def _owned_conversation(conversation_id: UUID, *, token: str) -> dict[str, Any]:
    rows = await _request("/rest/v1/agrilens_conversations", token=token,
                          params={"select": "id,title,created_at,updated_at", "id": f"eq.{conversation_id}", "limit": "1"})
    if not rows:
        raise HTTPException(404, "Conversation not found")
    return rows[0]


class CreateConversationRequest(BaseModel):
    title: str = Field(default="New conversation", min_length=1, max_length=300)


@router.post("")
async def create_conversation(request: CreateConversationRequest,
                              user_id: str = Depends(require_user),
                              authorization: str | None = Header(default=None)):
    token = _bearer(authorization)
    now = datetime.now(timezone.utc).isoformat()
    row = {"id": str(uuid4()), "owner_id": user_id, "title": request.title.strip() or "New conversation",
           "created_at": now, "updated_at": now}
    rows = await _request("/rest/v1/agrilens_conversations", token=token, method="POST", json=[row],
                          prefer="return=representation")
    return rows[0]


@router.get("")
async def list_conversations(user_id: str = Depends(require_user),
                             authorization: str | None = Header(default=None),
                             limit: int = Query(default=100, ge=1, le=100),
                             offset: int = Query(default=0, ge=0)):
    token = _bearer(authorization)
    rows = await _request("/rest/v1/agrilens_conversations", token=token,
                          params={"select": "id,title,created_at,updated_at", "order": "updated_at.desc",
                                  "limit": str(limit), "offset": str(offset)})
    return {"conversations": rows or []}


@router.get("/{conversation_id}")
async def get_conversation(conversation_id: UUID, user_id: str = Depends(require_user),
                           authorization: str | None = Header(default=None)):
    del user_id
    token = _bearer(authorization)
    conversation = await _owned_conversation(conversation_id, token=token)
    messages = []
    offset = 0
    while True:
        page = await _request("/rest/v1/agrilens_messages", token=token,
                              params={"select": "id,conversation_id,role,content_type,text_content,image_object_path,lifecycle,failure_reason,created_at,updated_at,response_metadata",
                                      "conversation_id": f"eq.{conversation_id}", "order": "created_at.asc,id.asc",
                                      "limit": "500", "offset": str(offset)})
        messages.extend(page or [])
        if len(page or []) < 500:
            break
        offset += 500
    predictions = []
    message_ids = [row["id"] for row in messages]
    for start in range(0, len(message_ids), 100):
        ids = message_ids[start:start + 100]
        page = await _request("/rest/v1/agrilens_predictions", token=token,
                              params={"select": "*", "message_id": f"in.({','.join(ids)})"})
        predictions.extend(page or [])
    prediction_by_message = {str(item["message_id"]): item for item in predictions or []}
    for message in messages or []:
        message.pop("image_object_path", None)
        message["image_url"] = (f"/v1/conversations/{conversation_id}/messages/{message['id']}/image"
                                if message.get("content_type") == "image" else None)
        message["prediction"] = prediction_by_message.get(str(message["id"]))
    return {"conversation": conversation, "messages": messages or []}


@router.get("/{conversation_id}/messages/{message_id}/image")
async def get_message_image(conversation_id: UUID, message_id: UUID,
                            user_id: str = Depends(require_user),
                            authorization: str | None = Header(default=None)):
    del user_id
    token = _bearer(authorization)
    await _owned_conversation(conversation_id, token=token)
    rows = await _request("/rest/v1/agrilens_messages", token=token,
                          params={"select": "image_object_path", "id": f"eq.{message_id}",
                                  "conversation_id": f"eq.{conversation_id}", "limit": "1"})
    if not rows or not rows[0].get("image_object_path"):
        raise HTTPException(404, "Conversation image not found")
    path = quote(str(rows[0]["image_object_path"]), safe="/")
    result = await _request(f"/storage/v1/object/agrilens-history/{path}", token=token)
    return Response(content=result.content, media_type=result.headers.get("content-type", "image/jpeg"))


@router.delete("/{conversation_id}", status_code=204)
async def delete_conversation(conversation_id: UUID, user_id: str = Depends(require_user),
                              authorization: str | None = Header(default=None)):
    del user_id
    token = _bearer(authorization)
    await _owned_conversation(conversation_id, token=token)
    messages = await _request("/rest/v1/agrilens_messages", token=token,
                              params={"select": "image_object_path", "conversation_id": f"eq.{conversation_id}"})
    await _request(f"/rest/v1/agrilens_conversations?id=eq.{conversation_id}", token=token, method="DELETE")
    for message in messages or []:
        path = message.get("image_object_path")
        if path:
            await _request(f"/storage/v1/object/agrilens-history/{quote(str(path), safe='/')}", token=token,
                           method="DELETE")
    return Response(status_code=204)


async def save_diagnosis(*, conversation_id: UUID, user_id: str, token: str,
                         image: bytes, mime_type: str, prediction: dict[str, Any]) -> None:
    await _owned_conversation(conversation_id, token=token)
    if image.startswith(b"\xff\xd8\xff"):
        mime_type = "image/jpeg"
    elif image.startswith(b"\x89PNG\r\n\x1a\n"):
        mime_type = "image/png"
    elif len(image) >= 12 and image[:4] == b"RIFF" and image[8:12] == b"WEBP":
        mime_type = "image/webp"
    else:
        raise HTTPException(415, "Upload a valid JPEG, PNG, or WebP image")
    message_id = uuid4()
    object_path = f"{user_id}/{conversation_id}/{message_id}.{ {'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp'}.get(mime_type, 'jpg') }"
    await _request(f"/storage/v1/object/agrilens-history/{quote(object_path, safe='/')}", token=token,
                   method="POST", content=image, content_type=mime_type)
    now = datetime.now(timezone.utc).isoformat()
    try:
        await _request("/rest/v1/agrilens_messages", token=token, method="POST", json=[{
            "id": str(message_id), "owner_id": user_id, "conversation_id": str(conversation_id),
            "role": "user", "content_type": "image", "image_object_path": object_path,
            "lifecycle": "complete", "created_at": now, "updated_at": now,
        }])
        await _request("/rest/v1/agrilens_predictions", token=token, method="POST", json=[{
            "id": str(uuid4()), "owner_id": user_id, "message_id": str(message_id),
            **(prediction | {"decision_state": {"possible_match": "possibleMatch",
                                                  "unsupported_or_unclear": "unsupportedOrUnclear"}
                                .get(str(prediction.get("decision_state")), prediction.get("decision_state"))}),
            "created_at": now,
        }])
        await _request(f"/rest/v1/agrilens_conversations?id=eq.{conversation_id}", token=token,
                       method="PATCH", json={"updated_at": now})
    except HTTPException:
        await _request(f"/storage/v1/object/agrilens-history/{quote(object_path, safe='/')}", token=token, method="DELETE")
        raise


async def conversation_answer_context(*, conversation_id: UUID, token: str) -> tuple[dict[str, Any], list[dict[str, str]]]:
    await _owned_conversation(conversation_id, token=token)
    messages = await _request("/rest/v1/agrilens_messages", token=token,
                              params={"select": "id,role,content_type,text_content,lifecycle,created_at",
                                      "conversation_id": f"eq.{conversation_id}", "order": "created_at.asc", "limit": "500"})
    image_ids = [row["id"] for row in messages or [] if row.get("content_type") == "image"]
    if not image_ids:
        raise HTTPException(409, "Analyze a leaf photo before asking a follow-up")
    predictions = await _request("/rest/v1/agrilens_predictions", token=token,
                                 params={"select": "*", "message_id": f"in.({','.join(image_ids)})", "order": "created_at.desc"})
    if not predictions:
        raise HTTPException(409, "The latest leaf image has no saved prediction")
    prediction = predictions[0]
    prediction["decision_state"] = prediction["decision_state"].replace("possibleMatch", "possible_match").replace("unsupportedOrUnclear", "unsupported_or_unclear")
    prior = [{"role": row["role"], "content": row["text_content"]}
             for row in messages or [] if row.get("content_type") == "text" and row.get("lifecycle") == "complete"
             and row.get("text_content")]
    return prediction, prior


async def save_answer_messages(*, conversation_id: UUID, user_id: str, token: str,
                               follow_up: str | None, answer: str | None = None,
                               metadata: dict[str, Any] | None = None, failure: str | None = None) -> None:
    created = datetime.now(timezone.utc)
    now = created.isoformat()
    if follow_up:
        await _request("/rest/v1/agrilens_messages", token=token, method="POST", json=[{
            "id": str(uuid4()), "owner_id": user_id, "conversation_id": str(conversation_id),
            "role": "user", "content_type": "text", "text_content": follow_up,
            "lifecycle": "complete", "created_at": now, "updated_at": now,
        }])
    assistant = {"id": str(uuid4()), "owner_id": user_id, "conversation_id": str(conversation_id),
                 "role": "assistant", "content_type": "text", "text_content": answer,
                 "lifecycle": "failed" if failure else "complete", "failure_reason": failure,
                 "response_metadata": metadata or {}, "created_at": (created + timedelta(milliseconds=1)).isoformat(),
                 "updated_at": (created + timedelta(milliseconds=1)).isoformat()}
    await _request("/rest/v1/agrilens_messages", token=token, method="POST", json=[assistant])
    await _request(f"/rest/v1/agrilens_conversations?id=eq.{conversation_id}", token=token,
                   method="PATCH", json={"updated_at": now})
