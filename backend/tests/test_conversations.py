from __future__ import annotations

import os
import unittest
from unittest.mock import AsyncMock, patch
from uuid import UUID

import httpx
from types import SimpleNamespace

from app.auth import require_user
from app.conversations import conversation_answer_context, save_diagnosis
from app.main import app


CONVERSATION_ID = "da622fec-94f6-4cc7-9a1f-2398f2cac944"


class ConversationApiTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.original_url = os.environ.get("SUPABASE_URL")
        self.original_key = os.environ.get("SUPABASE_ANON_KEY")
        os.environ["SUPABASE_URL"] = "https://example.supabase.co"
        os.environ["SUPABASE_ANON_KEY"] = "anon-test"
        app.dependency_overrides[require_user] = lambda: "test-user"
        self.client = httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test")

    async def asyncTearDown(self):
        await self.client.aclose()
        app.dependency_overrides.pop(require_user, None)
        if self.original_url is None:
            os.environ.pop("SUPABASE_URL", None)
        else:
            os.environ["SUPABASE_URL"] = self.original_url
        if self.original_key is None:
            os.environ.pop("SUPABASE_ANON_KEY", None)
        else:
            os.environ["SUPABASE_ANON_KEY"] = self.original_key

    async def test_create_and_list_conversations_use_authenticated_routes(self):
        created = {"id": CONVERSATION_ID, "title": "Tomato", "created_at": "2026-10-26T10:00:00Z", "updated_at": "2026-10-26T10:00:00Z"}
        with patch("app.conversations._request", new=AsyncMock(return_value=[created])) as request:
            response = await self.client.post("/v1/conversations", headers={"Authorization": "Bearer test-token"}, json={"title": "Tomato"})
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["id"], CONVERSATION_ID)
        request.assert_awaited_once()

        with patch("app.conversations._request", new=AsyncMock(return_value=[created])):
            response = await self.client.get("/v1/conversations", headers={"Authorization": "Bearer test-token"})
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["conversations"][0]["title"], "Tomato")

    async def test_detail_includes_prediction_metadata_and_mediated_image_url(self):
        conversation = {"id": CONVERSATION_ID, "title": "Tomato", "created_at": "2026-10-26T10:00:00Z", "updated_at": "2026-10-26T10:00:00Z"}
        message = {"id": "6e1b5fa8-85f0-462a-8ef0-1b94bc70054f", "conversation_id": CONVERSATION_ID,
                   "role": "user", "content_type": "image", "text_content": None, "image_object_path": "test/path.jpg",
                   "lifecycle": "complete", "failure_reason": None, "created_at": "2026-10-26T10:00:00Z",
                   "updated_at": "2026-10-26T10:00:00Z", "response_metadata": {}}
        prediction = {"id": "2c95c716-f85b-4b55-906e-cc3875c94a8e", "message_id": message["id"], "class_id": 6}
        async def fake_request(path, **kwargs):
            if path.endswith("agrilens_conversations"):
                return [conversation]
            if path.endswith("agrilens_messages"):
                return [message]
            return [prediction]
        with patch("app.conversations._request", side_effect=fake_request):
            response = await self.client.get(f"/v1/conversations/{CONVERSATION_ID}", headers={"Authorization": "Bearer test-token"})
        self.assertEqual(response.status_code, 200, response.text)
        row = response.json()["messages"][0]
        self.assertNotIn("image_object_path", row)
        self.assertEqual(row["prediction"]["class_id"], 6)
        self.assertTrue(row["image_url"].endswith("/image"))

    async def test_image_read_is_proxied_only_after_conversation_ownership_check(self):
        message_id = "6e1b5fa8-85f0-462a-8ef0-1b94bc70054f"
        storage_response = httpx.Response(200, content=b"original-photo", headers={"content-type": "image/jpeg"})
        async def fake_request(path, **kwargs):
            if path.endswith("agrilens_conversations"):
                return [{"id": CONVERSATION_ID}]
            if path.endswith("agrilens_messages"):
                return [{"image_object_path": "test-user/thread/photo.jpg"}]
            return storage_response
        with patch("app.conversations._request", side_effect=fake_request):
            response = await self.client.get(
                f"/v1/conversations/{CONVERSATION_ID}/messages/{message_id}/image",
                headers={"Authorization": "Bearer test-token"},
            )
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.content, b"original-photo")
        self.assertEqual(response.headers["content-type"], "image/jpeg")

    async def test_other_users_conversation_is_not_found(self):
        with patch("app.conversations._request", new=AsyncMock(return_value=[])):
            response = await self.client.get(
                f"/v1/conversations/{CONVERSATION_ID}",
                headers={"Authorization": "Bearer test-token"},
            )
        self.assertEqual(response.status_code, 404)

    async def test_delete_removes_database_record_and_original_photo(self):
        calls = []
        async def fake_request(path, **kwargs):
            calls.append((path, kwargs.get("method", "GET")))
            if path.endswith("agrilens_conversations"):
                return [{"id": CONVERSATION_ID}]
            if path.endswith("agrilens_messages"):
                return [{"image_object_path": "test-user/thread/photo.jpg"}]
            return None
        with patch("app.conversations._request", side_effect=fake_request):
            response = await self.client.delete(
                f"/v1/conversations/{CONVERSATION_ID}",
                headers={"Authorization": "Bearer test-token"},
            )
        self.assertEqual(response.status_code, 204, response.text)
        self.assertIn((f"/rest/v1/agrilens_conversations?id=eq.{CONVERSATION_ID}", "DELETE"), calls)
        self.assertIn(("/storage/v1/object/agrilens-history/test-user/thread/photo.jpg", "DELETE"), calls)

    async def test_image_and_prediction_are_saved_with_private_object_path(self):
        prediction = {"class_id": 2, "crop": "maize", "condition": "gray_leaf_spot", "decision_state": "possible_match",
                      "top_logit": 3, "calibrated_score": .8, "margin": .2, "prototype_similarity": None,
                      "model_version": "v1", "preprocess_version": "p1", "failure_reason": None}
        with patch("app.conversations._request", new=AsyncMock(return_value=[{"id": CONVERSATION_ID}])) as request:
            await save_diagnosis(conversation_id=UUID(CONVERSATION_ID), user_id="test-user", token="test-token",
                                 image=b"\xff\xd8\xffimage", mime_type="application/octet-stream", prediction=prediction)
        self.assertGreaterEqual(request.await_count, 5)
        storage = request.await_args_list[1].kwargs
        self.assertIn("test-user/", request.await_args_list[1].args[0])
        self.assertEqual(storage["method"], "POST")
        persisted_prediction = request.await_args_list[3].kwargs["json"][0]
        self.assertEqual(persisted_prediction["decision_state"], "possibleMatch")

    async def test_diagnosis_route_requires_and_persists_selected_conversation(self):
        result = SimpleNamespace(class_id=2, crop="maize", condition="gray_leaf_spot",
            decision_state="possible_match", top_logit=3.0, calibrated_score=.8, margin=.2,
            prototype_similarity=None, model_version="v1", preprocess_version="p1", failure_reason=None)
        with (patch("app.main.get_diagnosis_model", return_value=SimpleNamespace(predict=lambda image: result)),
              patch("app.main.save_diagnosis", new=AsyncMock()) as save):
            response = await self.client.post("/v1/diagnoses", headers={"Authorization": "Bearer test-token"},
                data={"conversation_id": CONVERSATION_ID}, files={"image": ("leaf.jpg", b"leaf-bytes", "image/jpeg")})
        self.assertEqual(response.status_code, 200, response.text)
        save.assert_awaited_once()
        self.assertEqual(str(save.await_args.kwargs["conversation_id"]), CONVERSATION_ID)
        self.assertEqual(save.await_args.kwargs["image"], b"leaf-bytes")

    async def test_answer_context_loads_saved_prediction_and_turns(self):
        conversation = [{"id": CONVERSATION_ID}]
        messages = [
            {"id": "6e1b5fa8-85f0-462a-8ef0-1b94bc70054f", "role": "user", "content_type": "image", "lifecycle": "complete"},
            {"id": "7e1b5fa8-85f0-462a-8ef0-1b94bc70054f", "role": "user", "content_type": "text", "text_content": "What now?", "lifecycle": "complete"},
        ]
        prediction = {"message_id": messages[0]["id"], "class_id": 6, "decision_state": "possibleMatch"}
        async def fake_request(path, **kwargs):
            if path.endswith("agrilens_conversations"):
                return conversation
            if path.endswith("agrilens_messages"):
                return messages
            return [prediction]
        with patch("app.conversations._request", side_effect=fake_request):
            saved_prediction, turns = await conversation_answer_context(conversation_id=UUID(CONVERSATION_ID), token="test-token")
        self.assertEqual(saved_prediction["decision_state"], "possible_match")
        self.assertEqual(turns, [{"role": "user", "content": "What now?"}])

