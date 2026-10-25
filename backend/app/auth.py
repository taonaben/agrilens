from __future__ import annotations

import os

import httpx
from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel, Field

router = APIRouter(tags=["authentication"])


class Credentials(BaseModel):
    email: str = Field(min_length=3, max_length=320)
    password: str = Field(min_length=8, max_length=128)


def _supabase_config() -> tuple[str, str]:
    supabase_url = os.getenv("SUPABASE_URL", "").rstrip("/")
    anon_key = os.getenv("SUPABASE_ANON_KEY", "")
    if not supabase_url or not anon_key:
        raise HTTPException(
            status_code=503, detail="Authentication service is not configured"
        )
    return supabase_url, anon_key


async def _auth_request(path: str, credentials: Credentials) -> dict:
    supabase_url, anon_key = _supabase_config()
    try:
        async with httpx.AsyncClient(timeout=8) as client:
            response = await client.post(
                f"{supabase_url}/auth/v1/{path}",
                headers={"apikey": anon_key, "Content-Type": "application/json"},
                json={
                    "email": credentials.email.strip(),
                    "password": credentials.password,
                },
            )
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=503, detail="Could not reach the authentication service"
        ) from exc

    if response.is_error:
        # Keep provider details out of the API response; they can contain internal context.
        if response.status_code in (400, 401, 422):
            detail = (
                "Email or password is invalid"
                if path.endswith("token?grant_type=password")
                else "Could not create account"
            )
            raise HTTPException(status_code=400, detail=detail)
        raise HTTPException(
            status_code=503, detail="Authentication service is unavailable"
        )
    try:
        return response.json()
    except ValueError as exc:
        raise HTTPException(
            status_code=503,
            detail="Authentication service returned an invalid response",
        ) from exc


@router.post("/register", include_in_schema=False)
@router.post("/auth/register")
async def register(credentials: Credentials):
    """Create an account. Supabase email confirmation settings determine session availability."""
    return await _auth_request("signup", credentials)


@router.post("/login", include_in_schema=False)
@router.post("/auth/login")
async def login(credentials: Credentials):
    """Sign in with email and password and return Supabase session tokens."""
    return await _auth_request("token?grant_type=password", credentials)


async def require_user(authorization: str | None = Header(default=None)) -> str:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="A signed-in user is required")
    supabase_url, anon_key = _supabase_config()

    token = authorization.split(" ", 1)[1].strip()
    try:
        async with httpx.AsyncClient(timeout=8) as client:
            response = await client.get(
                f"{supabase_url}/auth/v1/user",
                headers={"apikey": anon_key, "Authorization": f"Bearer {token}"},
            )
        if response.status_code != 200:
            raise HTTPException(
                status_code=401, detail="The session is invalid or expired"
            )
        user_id = response.json().get("id")
        if not isinstance(user_id, str) or not user_id:
            raise HTTPException(
                status_code=401, detail="The session did not identify a user"
            )
        return user_id
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=503, detail="Could not verify the signed-in session"
        ) from exc
