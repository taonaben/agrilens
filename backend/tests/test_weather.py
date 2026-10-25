from __future__ import annotations

import os
import unittest
from unittest.mock import AsyncMock, patch

import httpx
from fastapi import HTTPException
from redis.exceptions import ConnectionError as RedisConnectionError

from app import weather
from app.auth import require_user
from app.main import app


def _current_weather() -> dict:
    return {
        "coord": {"lat": -17.8262, "lon": 31.053},
        "weather": [{"id": 800, "main": "Clear", "description": "clear sky", "icon": "01d"}],
        "main": {"temp": 24.5, "feels_like": 24.1, "humidity": 42, "pressure": 1012},
        "wind": {"speed": 3.2, "deg": 120},
        "clouds": {"all": 0},
        "visibility": 10000,
        "dt": 1792958400,
        "timezone": 7200,
        "name": "Harare",
        "sys": {"country": "ZW"},
    }


def _forecast() -> dict:
    return {
        "list": [
            {
                "dt": 1792969200,
                "main": {"temp": 25.0, "feels_like": 24.8, "humidity": 40},
                "wind": {"speed": 2.5},
                "pop": 0.2,
                "rain": {"3h": 0.1},
                "weather": [{"id": 801, "main": "Clouds", "description": "few clouds", "icon": "02d"}],
            }
        ]
    }


class FakeRedis:
    def __init__(self, *, unavailable: bool = False):
        self.values: dict[str, str] = {}
        self.ttls: dict[str, int] = {}
        self.unavailable = unavailable

    async def get(self, key: str):
        if self.unavailable:
            raise RedisConnectionError("Redis unavailable")
        return self.values.get(key)

    async def set(self, key: str, value: str, *, ex: int):
        if self.unavailable:
            raise RedisConnectionError("Redis unavailable")
        self.values[key] = value
        self.ttls[key] = ex


class WeatherEndpointTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.previous_api_key = os.environ.get("OPENWEATHER_API_KEY")
        os.environ["OPENWEATHER_API_KEY"] = "server-secret"
        self.redis = FakeRedis()
        app.state.weather_redis = self.redis
        app.dependency_overrides[require_user] = lambda: "test-user"
        self.client = httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app), base_url="http://test"
        )

    async def asyncTearDown(self):
        await self.client.aclose()
        app.dependency_overrides.pop(require_user, None)
        if self.previous_api_key is None:
            os.environ.pop("OPENWEATHER_API_KEY", None)
        else:
            os.environ["OPENWEATHER_API_KEY"] = self.previous_api_key

    async def test_fetches_current_and_five_day_forecast_and_caches_them(self):
        async def provider(_client, path, params):
            self.assertEqual(params["units"], "metric")
            self.assertEqual(params["appid"], "server-secret")
            return _current_weather() if path == "weather" else _forecast()

        with patch.object(weather, "_fetch_weather", new=AsyncMock(side_effect=provider)) as fetch:
            response = await self.client.get("/v1/weather?lat=-17.8262&lon=31.053")
            self.assertEqual(response.status_code, 200, response.text)
            body = response.json()
            self.assertEqual(body["city_name"], "Harare")
            self.assertEqual(body["current"]["temperature_c"], 24.5)
            self.assertEqual(body["forecast"][0]["rain_3h_mm"], 0.1)
            self.assertNotIn("server-secret", response.text)
            self.assertEqual(fetch.await_count, 2)
            self.assertEqual(self.redis.ttls["weather:v1:current:-17.826:31.053"], 600)
            self.assertEqual(self.redis.ttls["weather:v1:forecast:-17.826:31.053"], 1800)

            cached = await self.client.get("/v1/weather?lat=-17.8263&lon=31.0528")
            self.assertEqual(cached.status_code, 200)
            self.assertEqual(fetch.await_count, 2)

    async def test_rejects_out_of_range_coordinates(self):
        for query in ("lat=91&lon=31", "lat=NaN&lon=31", "lat=0&lon=Infinity"):
            with self.subTest(query=query):
                response = await self.client.get(f"/v1/weather?{query}")
                self.assertEqual(response.status_code, 422)

    async def test_requires_authentication(self):
        app.dependency_overrides.pop(require_user, None)
        response = await self.client.get("/v1/weather?lat=0&lon=0")
        self.assertEqual(response.status_code, 401)

    async def test_provider_failure_returns_service_unavailable(self):
        with patch.object(
            weather,
            "_fetch_weather",
            new=AsyncMock(side_effect=HTTPException(503, "Weather provider is unavailable")),
        ):
            response = await self.client.get("/v1/weather?lat=0&lon=0")
        self.assertEqual(response.status_code, 503)

    async def test_redis_outage_does_not_block_provider_fetch(self):
        app.state.weather_redis = FakeRedis(unavailable=True)

        async def provider(_client, path, _params):
            return _current_weather() if path == "weather" else _forecast()

        with patch.object(weather, "_fetch_weather", new=AsyncMock(side_effect=provider)) as fetch:
            response = await self.client.get("/v1/weather?lat=0&lon=0")
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(fetch.await_count, 2)


if __name__ == "__main__":
    unittest.main()
