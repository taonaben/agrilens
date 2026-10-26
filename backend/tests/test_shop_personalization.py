from __future__ import annotations

import unittest
from unittest.mock import AsyncMock, patch

import httpx

from app.auth import require_user
from app.embeddings import EMBEDDING_DIMENSIONS, EmbeddingUnavailable
from app.main import app


def _vector(first: float, second: float) -> list[float]:
    tail = [0.0] * (EMBEDDING_DIMENSIONS - 2)
    return [first, second, *tail]


def _product_row(*, product_id: str, name: str, embedding: list[float] | None) -> dict:
    return {
        "id": product_id,
        "sku": f"SKU-{name.upper()}",
        "name": name,
        "description": f"{name} description",
        "price": "12.50",
        "currency": "USD",
        "stock_quantity": 3,
        "crops": ["tomato"],
        "conditions": ["late_blight"],
        "recommended_uses": ["use as directed"],
        "evidence_source_url": "https://example.org/evidence",
        "evidence_reviewed_at": "2026-10-20",
        "stock_verified_at": "2026-10-24",
        "image_path": f"{name}/item.webp",
        "search_embedding": embedding,
        "search_embedding_model": "gemini-embedding-2",
        "active": True,
    }


class ShopPersonalizationTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        app.dependency_overrides[require_user] = lambda: "test-user"
        self.client = httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app), base_url="http://test"
        )

    async def asyncTearDown(self):
        await self.client.aclose()
        app.dependency_overrides.pop(require_user, None)

    async def test_products_are_ranked_with_scan_and_order_context(self):
        rows = [
            _product_row(
                product_id="00000000-0000-0000-0000-000000000001",
                name="alpha",
                embedding=_vector(0.0, 1.0),
            ),
            _product_row(
                product_id="00000000-0000-0000-0000-000000000002",
                name="zeta",
                embedding=_vector(1.0, 0.0),
            ),
        ]

        async def fake_rest(path: str, **kwargs):  # noqa: ANN003
            if path == "shop_products":
                return rows
            if path == "agrilens_predictions":
                return [{"crop": "tomato", "condition": "late_blight", "decision_state": "possibleMatch"}]
            if path == "shop_orders":
                return [{
                    "id": "9cc6f58f-b59f-4b00-a991-ff4f3619c3d8",
                    "shop_order_items": [{"name_snapshot": "Copper fungicide", "sku_snapshot": "F-1", "quantity": 1}],
                }]
            raise AssertionError(f"Unexpected path {path}")

        with (
            patch("app.shop._rest", new=AsyncMock(side_effect=fake_rest)) as rest,
            patch("app.shop.embed_text", new=AsyncMock(return_value=_vector(1.0, 0.0))),
        ):
            response = await self.client.get(
                "/v1/products", headers={"Authorization": "******"}
            )
        self.assertEqual(response.status_code, 200, response.text)
        payload = response.json()
        self.assertEqual(payload[0]["name"], "zeta")
        self.assertEqual(payload[1]["name"], "alpha")
        queried_paths = [call.args[0] for call in rest.await_args_list]
        self.assertIn("agrilens_predictions", queried_paths)
        self.assertIn("shop_orders", queried_paths)

    async def test_products_fall_back_to_default_order_when_no_personalization_context(self):
        rows = [
            _product_row(
                product_id="00000000-0000-0000-0000-000000000011",
                name="alpha",
                embedding=_vector(0.0, 1.0),
            ),
            _product_row(
                product_id="00000000-0000-0000-0000-000000000012",
                name="zeta",
                embedding=_vector(1.0, 0.0),
            ),
        ]

        async def fake_rest(path: str, **kwargs):  # noqa: ANN003
            if path == "shop_products":
                return rows
            if path == "agrilens_predictions":
                return []
            if path == "shop_orders":
                return []
            raise AssertionError(f"Unexpected path {path}")

        with (
            patch("app.shop._rest", new=AsyncMock(side_effect=fake_rest)),
            patch("app.shop.embed_text", new=AsyncMock()) as embed,
        ):
            response = await self.client.get(
                "/v1/products", headers={"Authorization": "******"}
            )
        self.assertEqual(response.status_code, 200, response.text)
        payload = response.json()
        self.assertEqual([item["name"] for item in payload], ["alpha", "zeta"])
        embed.assert_not_awaited()

    async def test_products_fall_back_to_default_order_when_embedding_fails(self):
        rows = [
            _product_row(
                product_id="00000000-0000-0000-0000-000000000021",
                name="alpha",
                embedding=_vector(0.0, 1.0),
            ),
            _product_row(
                product_id="00000000-0000-0000-0000-000000000022",
                name="zeta",
                embedding=_vector(1.0, 0.0),
            ),
        ]

        async def fake_rest(path: str, **kwargs):  # noqa: ANN003
            if path == "shop_products":
                return rows
            if path == "agrilens_predictions":
                return [{"crop": "tomato", "condition": "late_blight", "decision_state": "possibleMatch"}]
            if path == "shop_orders":
                return [{"shop_order_items": [{"name_snapshot": "Copper fungicide", "sku_snapshot": "F-1", "quantity": 1}]}]
            raise AssertionError(f"Unexpected path {path}")

        with (
            patch("app.shop._rest", new=AsyncMock(side_effect=fake_rest)),
            patch("app.shop.embed_text", new=AsyncMock(side_effect=EmbeddingUnavailable("disabled"))),
        ):
            response = await self.client.get(
                "/v1/products", headers={"Authorization": "******"}
            )
        self.assertEqual(response.status_code, 200, response.text)
        payload = response.json()
        self.assertEqual([item["name"] for item in payload], ["alpha", "zeta"])
