from __future__ import annotations

import os
import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

import httpx

from app import ai_context
from app.auth import require_user
from app.gemini import GeneratedAnswer, GeminiUnavailable, generate_answer
from app.embeddings import embed_texts
from app.main import app
from app.shop import ProductInput


PRODUCT_ID = "dd247012-37a1-4d5a-8f79-89253141d1dd"
SOURCE_ID = "1a76893c-270c-4f12-99e1-c03bb60c4c58"


def _prediction(decision_state: str = "possible_match") -> dict:
    return {
        "class_id": 6,
        "crop": "tomato",
        "condition": "late_blight",
        "decision_state": decision_state,
        "top_logit": 2.0,
        "calibrated_score": 0.8,
        "margin": 0.3,
        "prototype_similarity": None,
        "model_version": "test-model",
        "preprocess_version": "test-preprocess",
    }


def _product() -> dict:
    return {
        "id": PRODUCT_ID,
        "sku": "BLIGHT-01",
        "name": "Verified tomato care item",
        "description": "Catalog description",
        "price": "12.50",
        "currency": "USD",
        "stock_quantity": 4,
        "crops": ["tomato"],
        "conditions": ["late_blight"],
        "recommended_uses": ["Use for tomato late blight"] ,
        "evidence_source_url": "https://example.org/product-evidence",
        "evidence_reviewed_at": "2026-10-20",
        "stock_verified_at": "2026-10-24",
        "image_path": "BLIGHT-01/item.webp",
    }


def _guidance() -> dict:
    return {
        "id": SOURCE_ID,
        "source_title": "Tomato guidance",
        "source_organization": "Agriculture Department",
        "source_url": "https://example.org/tomato-guidance",
        "source_published_on": "2024-03-01",
        "reviewed_on": "2026-10-20",
        "topic": "late blight",
        "crop": "tomato",
        "condition": "late_blight",
        "content": "Remove infected debris and seek local extension advice.",
    }


class SmartAnswerTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.original_supabase_url = os.environ.get("SUPABASE_URL")
        os.environ["SUPABASE_URL"] = "https://example.supabase.co"
        app.state.weather_redis = None
        app.dependency_overrides[require_user] = lambda: "test-user"
        self.conversation_context = patch(
            "app.main.conversation_answer_context",
            new=AsyncMock(return_value=(_prediction(), [])),
        )
        self.answer_persistence = patch("app.main.save_answer_messages", new=AsyncMock())
        self.conversation_context_mock = self.conversation_context.start()
        self.answer_persistence_mock = self.answer_persistence.start()
        self.client = httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app), base_url="http://test"
        )

    async def asyncTearDown(self):
        await self.client.aclose()
        app.dependency_overrides.pop(require_user, None)
        self.conversation_context.stop()
        self.answer_persistence.stop()
        if self.original_supabase_url is None:
            os.environ.pop("SUPABASE_URL", None)
        else:
            os.environ["SUPABASE_URL"] = self.original_supabase_url

    async def test_answer_returns_only_model_selected_retrieved_products_and_sources(self):
        context = {"products": [_product()], "guidance": [_guidance()]}
        generated = GeneratedAnswer(
            answer="The scan suggests late blight. Follow the reviewed guidance.",
            product_ids=[PRODUCT_ID],
            source_ids=[SOURCE_ID],
        )
        with (
            patch("app.main.load_answer_context", new=AsyncMock(return_value=context)),
            patch("app.main.generate_answer", new=AsyncMock(return_value=generated)) as generate,
        ):
            response = await self.client.post(
                "/v1/answers",
                headers={"Authorization": "Bearer user-token"},
                json={"conversation_id": "da622fec-94f6-4cc7-9a1f-2398f2cac944", "user_follow_up": "What should I do?"},
            )
        self.assertEqual(response.status_code, 200, response.text)
        body = response.json()
        self.assertEqual(body["answer"], generated.answer)
        self.assertEqual(body["products"][0]["id"], PRODUCT_ID)
        self.assertTrue(body["products"][0]["image_url"].endswith("BLIGHT-01/item.webp"))
        self.assertEqual(body["sources"][0]["id"], SOURCE_ID)
        self.assertIsNone(generate.await_args.kwargs["weather"])
        self.assertEqual(generate.await_args.kwargs["response_language"], "english")
        self.answer_persistence_mock.assert_awaited_once()
        self.assertEqual(self.answer_persistence_mock.await_args.kwargs["metadata"]["sources"][0]["id"], SOURCE_ID)

    async def test_text_only_chat_answers_without_prediction_or_product_suggestions(self):
        self.conversation_context_mock.return_value = (None, [])
        context = {"products": [_product()], "guidance": [_guidance()]}
        generated = GeneratedAnswer(
            answer="For tomatoes, keep the soil evenly moist and avoid wetting the leaves.",
            product_ids=[PRODUCT_ID],
            source_ids=[SOURCE_ID],
        )
        with (
            patch("app.main.load_answer_context", new=AsyncMock(return_value=context)),
            patch("app.main.generate_answer", new=AsyncMock(return_value=generated)) as generate,
        ):
            response = await self.client.post(
                "/v1/answers",
                headers={"Authorization": "Bearer user-token"},
                json={"conversation_id": "da622fec-94f6-4cc7-9a1f-2398f2cac944",
                      "user_follow_up": "How should I water my tomatoes?"},
            )
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["products"], [])
        self.assertEqual(len(response.json()["sources"]), 1)
        self.assertIsNone(generate.await_args.kwargs["prediction"])
        self.assertEqual(generate.await_args.kwargs["products"], [])

    async def test_text_only_chat_answers_without_prediction_or_product_suggestions(self):
        self.conversation_context_mock.return_value = (None, [])
        context = {"products": [_product()], "guidance": [_guidance()]}
        generated = GeneratedAnswer(
            answer="For tomatoes, keep the soil evenly moist and avoid wetting the leaves.",
            product_ids=[PRODUCT_ID],
            source_ids=[SOURCE_ID],
        )
        with (
            patch("app.main.load_answer_context", new=AsyncMock(return_value=context)),
            patch("app.main.generate_answer", new=AsyncMock(return_value=generated)) as generate,
        ):
            response = await self.client.post(
                "/v1/answers",
                headers={"Authorization": "Bearer user-token"},
                json={"conversation_id": "da622fec-94f6-4cc7-9a1f-2398f2cac944",
                      "user_follow_up": "How should I water my tomatoes?"},
            )
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["products"], [])
        self.assertEqual(len(response.json()["sources"]), 1)
        self.assertIsNone(generate.await_args.kwargs["prediction"])
        self.assertEqual(generate.await_args.kwargs["products"], [])

    async def test_unretrieved_ids_are_dropped_and_uncertain_scan_cannot_return_products(self):
        self.conversation_context_mock.return_value = (_prediction("uncertain"), [])
        context = {"products": [_product()], "guidance": [_guidance()]}
        generated = GeneratedAnswer(
            answer="The result is uncertain; take another clear photo.",
            product_ids=["00000000-0000-0000-0000-000000000000", PRODUCT_ID],
            source_ids=["00000000-0000-0000-0000-000000000000", SOURCE_ID],
        )
        with (
            patch("app.main.load_answer_context", new=AsyncMock(return_value=context)),
            patch("app.main.generate_answer", new=AsyncMock(return_value=generated)),
        ):
            response = await self.client.post(
                "/v1/answers",
                headers={"Authorization": "Bearer user-token"},
                json={"conversation_id": "da622fec-94f6-4cc7-9a1f-2398f2cac944"},
            )
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["products"], [])
        self.assertEqual(len(response.json()["sources"]), 1)

    async def test_weather_failure_does_not_block_answer_generation(self):
        generated = GeneratedAnswer(answer="I do not have current weather for this answer.")
        with (
            patch("app.main.load_answer_context", new=AsyncMock(return_value={"products": [], "guidance": []})),
            patch("app.main.weather_for_coordinates", new=AsyncMock(side_effect=RuntimeError("offline"))),
            patch("app.main.generate_answer", new=AsyncMock(return_value=generated)) as generate,
        ):
            response = await self.client.post(
                "/v1/answers",
                headers={"Authorization": "Bearer user-token"},
                json={"conversation_id": "da622fec-94f6-4cc7-9a1f-2398f2cac944", "latitude": -17.8, "longitude": 31.0},
            )
        self.assertEqual(response.status_code, 200, response.text)
        self.assertIsNone(generate.await_args.kwargs["weather"])

    async def test_coordinates_must_be_supplied_as_a_pair(self):
        response = await self.client.post(
            "/v1/answers",
            headers={"Authorization": "Bearer user-token"},
                json={"conversation_id": "da622fec-94f6-4cc7-9a1f-2398f2cac944", "latitude": -17.8},
        )
        self.assertEqual(response.status_code, 422)

    async def test_answer_accepts_shona_and_ndebele_response_languages(self):
        with (
            patch("app.main.load_answer_context", new=AsyncMock(return_value={"products": [], "guidance": []})),
            patch("app.main.generate_answer", new=AsyncMock(return_value=GeneratedAnswer(answer="Mhinduro."))) as generate,
        ):
            for language in ("shona", "ndebele"):
                response = await self.client.post(
                    "/v1/answers",
                    headers={"Authorization": "Bearer user-token"},
                    json={"conversation_id": "da622fec-94f6-4cc7-9a1f-2398f2cac944", "response_language": language},
                )
                self.assertEqual(response.status_code, 200, response.text)
                self.assertEqual(generate.await_args.kwargs["response_language"], language)

    async def test_answer_rejects_unsupported_response_language(self):
        response = await self.client.post(
            "/v1/answers",
            headers={"Authorization": "Bearer user-token"},
            json={"conversation_id": "da622fec-94f6-4cc7-9a1f-2398f2cac944", "response_language": "swahili"},
        )
        self.assertEqual(response.status_code, 422)

    async def test_failed_gemini_response_is_persisted_and_marks_follow_up_saved(self):
        with (
            patch("app.main.load_answer_context", new=AsyncMock(return_value={"products": [], "guidance": []})),
            patch("app.main.generate_answer", new=AsyncMock(side_effect=GeminiUnavailable("Gemini is unavailable"))),
        ):
            response = await self.client.post(
                "/v1/answers",
                headers={"Authorization": "Bearer user-token"},
                json={"conversation_id": "da622fec-94f6-4cc7-9a1f-2398f2cac944", "user_follow_up": "What now?"},
            )
        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.headers["x-agrilens-followup-saved"], "true")
        self.answer_persistence_mock.assert_awaited_once()
        self.assertEqual(self.answer_persistence_mock.await_args.kwargs["follow_up"], "What now?")

    async def test_rule_based_recommendation_endpoint_is_retired(self):
        response = await self.client.get(
            "/v1/recommendations", headers={"Authorization": "Bearer user-token"}
        )
        self.assertEqual(response.status_code, 410)

    async def test_verified_product_requires_evidence_and_stock_review(self):
        with self.assertRaises(ValueError):
            ProductInput(
                sku="P-1", name="Product", price="10.00", currency="USD",
                stock_quantity=1, recommendation_eligible=True,
            )

    async def test_semantic_context_search_uses_same_embedding_model(self):
        with (
            patch("app.ai_context.embed_text", new=AsyncMock(return_value=[0.1] * 768)),
            patch("app.ai_context._rpc", new=AsyncMock(side_effect=[[{"id": PRODUCT_ID}], [{"id": SOURCE_ID}]])) as rpc,
        ):
            context = await ai_context.load_answer_context(
                bearer_token="user-token",
                prediction=_prediction(),
                prior_messages=[],
                user_follow_up="How can I protect my tomatoes?",
            )
        self.assertEqual(len(context["products"]), 1)
        self.assertEqual(len(context["guidance"]), 1)
        self.assertEqual(rpc.await_count, 2)
        self.assertEqual(rpc.await_args_list[0].kwargs["embedding_model"], "gemini-embedding-2")

    async def test_text_only_semantic_retrieval_searches_reviewed_guidance_not_products(self):
        with (
            patch("app.ai_context.embed_text", new=AsyncMock(return_value=[0.1] * 768)),
            patch("app.ai_context._rpc", new=AsyncMock(return_value=[_guidance()])) as rpc,
        ):
            context = await ai_context.load_answer_context(
                bearer_token="user-token", prediction=None, prior_messages=[],
                user_follow_up="How should I water my tomatoes?",
            )
        self.assertEqual(context["products"], [])
        self.assertEqual(context["guidance"], [_guidance()])
        rpc.assert_awaited_once()
        self.assertEqual(rpc.await_args.args[0], "search_reviewed_guidance")

    async def test_text_only_semantic_retrieval_searches_reviewed_guidance_not_products(self):
        with (
            patch("app.ai_context.embed_text", new=AsyncMock(return_value=[0.1] * 768)),
            patch("app.ai_context._rpc", new=AsyncMock(return_value=[_guidance()])) as rpc,
        ):
            context = await ai_context.load_answer_context(
                bearer_token="user-token", prediction=None, prior_messages=[],
                user_follow_up="How should I water my tomatoes?",
            )
        self.assertEqual(context["products"], [])
        self.assertEqual(context["guidance"], [_guidance()])
        rpc.assert_awaited_once()
        self.assertEqual(rpc.await_args.args[0], "search_reviewed_guidance")

    async def test_gemini_receives_context_and_returns_structured_fields(self):
        response = SimpleNamespace(
            candidates=[],
            parsed=None,
            text=(
                f'{{"answer":"Rain is forecast soon.","product_ids":["{PRODUCT_ID}"],'
                f'"source_ids":["{SOURCE_ID}"]}}'
            ),
        )

        class FakeAsyncClient:
            def __init__(self):
                self.models = SimpleNamespace(generate_content=AsyncMock(return_value=response))

        class FakeAio:
            async def __aenter__(self):
                self.client = FakeAsyncClient()
                return self.client

            async def __aexit__(self, *_args):
                return None

        fake_client = SimpleNamespace(aio=FakeAio())
        context = {
            "weather": {"current": {"temperature_c": 20}, "forecast": [{"rain_3h_mm": 5}]},
            "guidance": [_guidance()],
            "products": [_product()],
        }
        with patch.dict(os.environ, {"GEMINI_API_KEY": "test-key"}), patch(
            "app.gemini.genai.Client", return_value=fake_client
        ):
            generated = await generate_answer(
                prediction=_prediction(), prior_messages=[], user_follow_up="Should I water?",
                response_language="shona",
                weather=context["weather"], guidance=context["guidance"], products=context["products"],
            )
        call = fake_client.aio.client.models.generate_content.await_args
        prompt = call.kwargs["contents"]
        self.assertIn("temperature_c", prompt)
        self.assertIn("forecast", prompt)
        self.assertIn(PRODUCT_ID, prompt)
        self.assertIn(SOURCE_ID, prompt)
        self.assertIn("plausible causes", call.kwargs["config"].system_instruction)
        self.assertIn("naturally name any selected product", prompt)
        self.assertIn("Write the answer text in Shona", prompt)
        self.assertNotIn("confidence=0.700", prompt)
        self.assertEqual(call.kwargs["config"].response_mime_type, "application/json")
        self.assertEqual(generated.answer, "Rain is forecast soon.")
        self.assertEqual(generated.product_ids, [PRODUCT_ID])
        self.assertEqual(generated.source_ids, [SOURCE_ID])

    async def test_gemini_includes_model_score_only_when_farmer_asks(self):
        response = SimpleNamespace(
            candidates=[],
            parsed=None,
            text='{"answer":"The model score is 70%, but it is not a certainty.","product_ids":[],"source_ids":[]}',
        )

        class FakeAsyncClient:
            def __init__(self):
                self.models = SimpleNamespace(generate_content=AsyncMock(return_value=response))

        class FakeAio:
            async def __aenter__(self):
                self.client = FakeAsyncClient()
                return self.client

            async def __aexit__(self, *_args):
                return None

        fake_client = SimpleNamespace(aio=FakeAio())
        with patch.dict(os.environ, {"GEMINI_API_KEY": "test-key"}), patch(
            "app.gemini.genai.Client", return_value=fake_client
        ):
            await generate_answer(
                prediction=_prediction(), prior_messages=[],
                user_follow_up="What is the confidence score?",
            )
        prompt = fake_client.aio.client.models.generate_content.await_args.kwargs["contents"]
        self.assertIn("model confidence score=0.800", prompt)
        self.assertIn("model margin=0.300", prompt)

    async def test_gemini_text_only_prompt_does_not_claim_image_analysis(self):
        response = SimpleNamespace(candidates=[], parsed=None,
            text='{"answer":"Please attach a photo for a leaf assessment.","product_ids":[],"source_ids":[]}')
        class FakeAsyncClient:
            def __init__(self):
                self.models = SimpleNamespace(generate_content=AsyncMock(return_value=response))
        class FakeAio:
            async def __aenter__(self):
                self.client = FakeAsyncClient()
                return self.client
            async def __aexit__(self, *_args):
                return None
        fake_client = SimpleNamespace(aio=FakeAio())
        with patch.dict(os.environ, {"GEMINI_API_KEY": "test-key"}), patch(
            "app.gemini.genai.Client", return_value=fake_client
        ):
            await generate_answer(prediction=None, prior_messages=[],
                user_follow_up="What disease is on my maize leaf?", guidance=[], products=[])
        prompt = fake_client.aio.client.models.generate_content.await_args.kwargs["contents"]
        self.assertIn("No classifier result is attached", prompt)
        self.assertIn("ask them to attach a photo", prompt)

    async def test_embedding_batch_uses_individual_contents_and_768_dimensions(self):
        returned = [SimpleNamespace(values=[0.1] * 768), SimpleNamespace(values=[0.2] * 768)]

        class FakeAsyncClient:
            def __init__(self):
                self.models = SimpleNamespace(embed_content=AsyncMock(
                    return_value=SimpleNamespace(embeddings=returned)
                ))

        class FakeAio:
            async def __aenter__(self):
                self.client = FakeAsyncClient()
                return self.client

            async def __aexit__(self, *_args):
                return None

        fake_client = SimpleNamespace(aio=FakeAio())
        with patch("app.embeddings._client", return_value=fake_client):
            vectors = await embed_texts(["tomato blight", "maize rust"])
        call = fake_client.aio.client.models.embed_content.await_args
        self.assertEqual(len(call.kwargs["contents"]), 2)
        self.assertEqual(call.kwargs["config"].output_dimensionality, 768)
        self.assertEqual(len(vectors), 2)


if __name__ == "__main__":
    unittest.main()
