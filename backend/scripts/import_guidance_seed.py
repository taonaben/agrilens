from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

import httpx
from dotenv import load_dotenv


def main() -> None:
    load_dotenv()
    parser = argparse.ArgumentParser(description="Import reviewed AgriLens guidance seed data")
    parser.add_argument("--api-base-url", default="http://localhost:8888")
    args = parser.parse_args()
    admin_token = os.getenv("SHOP_ADMIN_TOKEN", "")
    if not admin_token:
        raise SystemExit("SHOP_ADMIN_TOKEN must be configured in the backend environment")

    source_path = Path(__file__).resolve().parents[1] / "assets" / "agronomy_guidance_seed.json"
    sources = json.loads(source_path.read_text(encoding="utf-8"))
    for source in sources:
        response = httpx.post(
            f"{args.api_base_url.rstrip('/')}/v1/guidance/import",
            headers={"X-Shop-Admin-Token": admin_token},
            json=source,
            timeout=90,
        )
        response.raise_for_status()
        print(response.json())


if __name__ == "__main__":
    main()
