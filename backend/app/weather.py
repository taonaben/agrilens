from __future__ import annotations

import asyncio
import json
import logging
import os
from datetime import UTC, datetime
from typing import Any

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel
from redis.exceptions import RedisError

from .auth import require_user

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/v1", tags=["weather"])

OPENWEATHER_BASE_URL = "https://api.openweathermap.org/data/2.5"
CURRENT_TTL_SECONDS = 10 * 60
FORECAST_TTL_SECONDS = 30 * 60


class CurrentWeather(BaseModel):
    observed_at: datetime
    temperature_c: float
    feels_like_c: float
    humidity_percent: int
    pressure_hpa: int
    wind_speed_m_s: float
    wind_direction_degrees: int | None = None
    cloudiness_percent: int | None = None
    visibility_m: int | None = None
    weather_code: int
    condition: str
    description: str
    icon: str | None = None


class ForecastPeriod(BaseModel):
    forecast_at: datetime
    temperature_c: float
    feels_like_c: float
    humidity_percent: int
    wind_speed_m_s: float
    precipitation_probability: float
    rain_3h_mm: float = 0
    snow_3h_mm: float = 0
    weather_code: int
    condition: str
    description: str
    icon: str | None = None


class WeatherResponse(BaseModel):
    latitude: float
    longitude: float
    city_name: str | None = None
    country_code: str | None = None
    timezone_offset_seconds: int
    current: CurrentWeather
    forecast: list[ForecastPeriod]


class CurrentDayWeatherResponse(BaseModel):
    latitude: float
    longitude: float
    city_name: str | None = None
    country_code: str | None = None
    timezone_offset_seconds: int
    current: CurrentWeather
    next_24_hours: list[ForecastPeriod]


class ForecastResponse(BaseModel):
    latitude: float
    longitude: float
    city_name: str | None = None
    country_code: str | None = None
    timezone_offset_seconds: int
    forecast: list[ForecastPeriod]


def _timestamp(value: Any) -> datetime:
    if not isinstance(value, (int, float)):
        raise ValueError("Weather timestamp is invalid")
    return datetime.fromtimestamp(value, tz=UTC)


def _weather_description(payload: dict[str, Any]) -> tuple[int, str, str, str | None]:
    weather = payload.get("weather")
    if not isinstance(weather, list) or not weather or not isinstance(weather[0], dict):
        raise ValueError("Weather conditions are missing")
    item = weather[0]
    return (
        int(item["id"]),
        str(item["main"]),
        str(item["description"]),
        str(item["icon"]) if item.get("icon") is not None else None,
    )


def _number(payload: dict[str, Any], key: str) -> float:
    value = payload.get(key)
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError(f"Weather field {key} is invalid")
    return float(value)


def _optional_number(payload: dict[str, Any], key: str) -> float | None:
    value = payload.get(key)
    if value is None:
        return None
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError(f"Weather field {key} is invalid")
    return float(value)


def _normalize_current(payload: dict[str, Any]) -> CurrentWeather:
    main = payload.get("main")
    wind = payload.get("wind") or {}
    clouds = payload.get("clouds") or {}
    if not isinstance(main, dict) or not isinstance(wind, dict) or not isinstance(clouds, dict):
        raise ValueError("Current weather response is invalid")
    code, condition, description, icon = _weather_description(payload)
    direction = _optional_number(wind, "deg")
    cloudiness = _optional_number(clouds, "all")
    visibility = _optional_number(payload, "visibility")
    return CurrentWeather(
        observed_at=_timestamp(payload.get("dt")),
        temperature_c=_number(main, "temp"),
        feels_like_c=_number(main, "feels_like"),
        humidity_percent=int(_number(main, "humidity")),
        pressure_hpa=int(_number(main, "pressure")),
        wind_speed_m_s=_number(wind, "speed"),
        wind_direction_degrees=int(direction) if direction is not None else None,
        cloudiness_percent=int(cloudiness) if cloudiness is not None else None,
        visibility_m=int(visibility) if visibility is not None else None,
        weather_code=code,
        condition=condition,
        description=description,
        icon=icon,
    )


def _normalize_forecast(payload: dict[str, Any]) -> list[ForecastPeriod]:
    entries = payload.get("list")
    if not isinstance(entries, list):
        raise ValueError("Forecast response is invalid")
    normalized = []
    for entry in entries:
        if not isinstance(entry, dict):
            raise ValueError("Forecast period is invalid")
        main = entry.get("main")
        wind = entry.get("wind") or {}
        if not isinstance(main, dict) or not isinstance(wind, dict):
            raise ValueError("Forecast period is invalid")
        code, condition, description, icon = _weather_description(entry)
        rain = entry.get("rain") or {}
        snow = entry.get("snow") or {}
        if not isinstance(rain, dict) or not isinstance(snow, dict):
            raise ValueError("Forecast precipitation is invalid")
        normalized.append(
            ForecastPeriod(
                forecast_at=_timestamp(entry.get("dt")),
                temperature_c=_number(main, "temp"),
                feels_like_c=_number(main, "feels_like"),
                humidity_percent=int(_number(main, "humidity")),
                wind_speed_m_s=_number(wind, "speed"),
                precipitation_probability=_number(entry, "pop"),
                rain_3h_mm=float(rain.get("3h", 0)),
                snow_3h_mm=float(snow.get("3h", 0)),
                weather_code=code,
                condition=condition,
                description=description,
                icon=icon,
            )
        )
    return normalized


async def _fetch_weather(client: httpx.AsyncClient, path: str, params: dict[str, Any]) -> dict[str, Any]:
    try:
        response = await client.get(f"{OPENWEATHER_BASE_URL}/{path}", params=params)
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=503, detail="Weather provider is unavailable") from exc
    if response.is_error:
        logger.warning("OpenWeather returned status %s for %s", response.status_code, path)
        raise HTTPException(status_code=503, detail="Weather provider is unavailable")
    try:
        data = response.json()
    except ValueError as exc:
        raise HTTPException(status_code=502, detail="Weather provider returned invalid data") from exc
    if not isinstance(data, dict):
        raise HTTPException(status_code=502, detail="Weather provider returned invalid data")
    return data


async def _read_cache(redis_client: Any, key: str) -> dict[str, Any] | None:
    if redis_client is None:
        return None
    try:
        encoded = await redis_client.get(key)
        if encoded is None:
            return None
        cached = json.loads(encoded)
        return cached if isinstance(cached, dict) else None
    except (RedisError, ValueError, TypeError) as exc:
        logger.warning("Weather cache read failed: %s", exc)
        return None


async def _write_cache(redis_client: Any, key: str, value: dict[str, Any], ttl: int) -> None:
    if redis_client is None:
        return
    try:
        await redis_client.set(key, json.dumps(value, separators=(",", ":")), ex=ttl)
    except (RedisError, TypeError, ValueError) as exc:
        logger.warning("Weather cache write failed: %s", exc)


@router.get("/weather", response_model=WeatherResponse)
async def get_weather(
    request: Request,
    lat: float = Query(ge=-90, le=90),
    lon: float = Query(ge=-180, le=180),
    user_id: str = Depends(require_user),
) -> WeatherResponse:
    del user_id  # Authentication is required; location is never persisted.
    redis_client = getattr(request.app.state, "weather_redis", None)
    return await weather_for_coordinates(lat, lon, redis_client)


@router.get("/weather/current", response_model=CurrentDayWeatherResponse)
async def get_current_weather(
    request: Request,
    lat: float = Query(ge=-90, le=90),
    lon: float = Query(ge=-180, le=180),
    user_id: str = Depends(require_user),
) -> CurrentDayWeatherResponse:
    del user_id
    redis_client = getattr(request.app.state, "weather_redis", None)
    return await current_day_for_coordinates(lat, lon, redis_client)


@router.get("/weather/forecast", response_model=ForecastResponse)
async def get_forecast(
    request: Request,
    lat: float = Query(ge=-90, le=90),
    lon: float = Query(ge=-180, le=180),
    user_id: str = Depends(require_user),
) -> ForecastResponse:
    del user_id
    redis_client = getattr(request.app.state, "weather_redis", None)
    return await forecast_for_coordinates(lat, lon, redis_client)


async def weather_for_coordinates(lat: float, lon: float, redis_client: Any = None) -> WeatherResponse:
    api_key = os.getenv("OPENWEATHER_API_KEY", "").strip()
    if not api_key:
        raise HTTPException(status_code=503, detail="Weather service is not configured")

    # Normalize both lookup and provider coordinates so entries in the same cache
    # bucket always represent the same requested point.
    latitude = round(lat, 3)
    longitude = round(lon, 3)
    coordinate_key = f"{latitude:.3f}:{longitude:.3f}"
    current_key = f"weather:v1:current:{coordinate_key}"
    forecast_key = f"weather:v1:forecast:{coordinate_key}"

    current_data, forecast_data = await asyncio.gather(
        _read_cache(redis_client, current_key),
        _read_cache(redis_client, forecast_key),
    )
    current_cache_miss = current_data is None
    forecast_cache_miss = forecast_data is None
    params = {"lat": latitude, "lon": longitude, "appid": api_key, "units": "metric"}
    async with httpx.AsyncClient(timeout=httpx.Timeout(8.0, connect=3.0)) as client:
        current_task = (
            asyncio.sleep(0, result=current_data)
            if current_data is not None
            else _fetch_weather(client, "weather", params)
        )
        forecast_task = (
            asyncio.sleep(0, result=forecast_data)
            if forecast_data is not None
            else _fetch_weather(client, "forecast", params)
        )
        current_data, forecast_data = await asyncio.gather(current_task, forecast_task)

    try:
        current = _normalize_current(current_data)
        forecast = _normalize_forecast(forecast_data)
        timezone_offset = int(_number(current_data, "timezone"))
        city_name = current_data.get("name")
        country_code = (current_data.get("sys") or {}).get("country")
        weather_result = WeatherResponse(
            latitude=latitude,
            longitude=longitude,
            city_name=str(city_name) if city_name else None,
            country_code=str(country_code) if country_code else None,
            timezone_offset_seconds=timezone_offset,
            current=current,
            forecast=forecast,
        )
    except (KeyError, TypeError, ValueError) as exc:
        logger.warning("OpenWeather returned a response that could not be normalized")
        raise HTTPException(status_code=502, detail="Weather provider returned invalid data") from exc

    # Cache only provider data that has passed normalization.
    writes = []
    if current_cache_miss:
        writes.append(_write_cache(redis_client, current_key, current_data, CURRENT_TTL_SECONDS))
    if forecast_cache_miss:
        writes.append(_write_cache(redis_client, forecast_key, forecast_data, FORECAST_TTL_SECONDS))
    if writes:
        await asyncio.gather(*writes)
    return weather_result


async def current_day_for_coordinates(
    lat: float, lon: float, redis_client: Any = None
) -> CurrentDayWeatherResponse:
    """Return observed conditions and forecast periods within the next 24 hours."""
    result = await weather_for_coordinates(lat, lon, redis_client)
    now = datetime.now(UTC)
    cutoff = now.timestamp() + 24 * 60 * 60
    next_24_hours = [
        period for period in result.forecast
        if now.timestamp() <= period.forecast_at.timestamp() <= cutoff
    ]
    return CurrentDayWeatherResponse(
        latitude=result.latitude,
        longitude=result.longitude,
        city_name=result.city_name,
        country_code=result.country_code,
        timezone_offset_seconds=result.timezone_offset_seconds,
        current=result.current,
        next_24_hours=next_24_hours,
    )


async def forecast_for_coordinates(
    lat: float, lon: float, redis_client: Any = None
) -> ForecastResponse:
    """Return the provider's full five-day forecast in three-hour periods."""
    api_key = os.getenv("OPENWEATHER_API_KEY", "").strip()
    if not api_key:
        raise HTTPException(status_code=503, detail="Weather service is not configured")
    latitude = round(lat, 3)
    longitude = round(lon, 3)
    cache_key = f"weather:v1:forecast:{latitude:.3f}:{longitude:.3f}"
    forecast_data = await _read_cache(redis_client, cache_key)
    cache_miss = forecast_data is None
    if cache_miss:
        params = {"lat": latitude, "lon": longitude, "appid": api_key, "units": "metric"}
        async with httpx.AsyncClient(timeout=httpx.Timeout(8.0, connect=3.0)) as client:
            forecast_data = await _fetch_weather(client, "forecast", params)
    try:
        forecast = _normalize_forecast(forecast_data)
        city = forecast_data.get("city") or {}
        if not isinstance(city, dict):
            raise ValueError("Forecast location is invalid")
        timezone_offset = int(_number(city, "timezone"))
        city_name = city.get("name")
        country_code = city.get("country")
    except (KeyError, TypeError, ValueError) as exc:
        logger.warning("OpenWeather returned a forecast that could not be normalized")
        raise HTTPException(status_code=502, detail="Weather provider returned invalid data") from exc
    if cache_miss:
        await _write_cache(redis_client, cache_key, forecast_data, FORECAST_TTL_SECONDS)
    return ForecastResponse(
        latitude=latitude,
        longitude=longitude,
        city_name=str(city_name) if city_name else None,
        country_code=str(country_code) if country_code else None,
        timezone_offset_seconds=timezone_offset,
        forecast=forecast,
    )
