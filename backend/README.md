# AgriLens FastAPI service

This service runs the nine-class TFLite classifier and requests bounded explanations from Gemini. Every protected endpoint requires a valid Supabase Auth access token; the Gemini key stays in the backend environment. The approved history design stores conversations in Supabase Postgres and original photos in the private `agrilens-history` Storage bucket, with FastAPI mediating all client access. Photos are retained until conversation deletion.

## Container setup

This is an independently buildable service folder in the repository. From `backend/`, copy `.env.example` to `.env`, fill in Supabase and Gemini settings, then run `docker compose up --build -d`. Compose builds only this folder, mounts `app/` into the container, and enables Uvicorn reload. Saving a backend source file in `app/` automatically restarts the API process; changes are shared both ways between the host and container. The ignored TFLite model and sibling training artifacts are mounted read-only and excluded from the image and Git context.

View logs with `docker compose logs -f api`; stop the local service with `docker compose down`. The container listens on port 8000. Configure the Flutter app's `AGRILENS_API_BASE_URL` to reach the API. Put a TLS ingress or load balancer in front of deployed containers. The API is stateless; scale replicas behind that ingress, and keep each container's `WEB_CONCURRENCY` conservative because each worker loads its own model into memory. Supabase holds durable application data; no conversation state is stored in the container.

For a platform that builds directly from the repository, set the Docker build context to `backend/` and the Dockerfile to `backend/Dockerfile`. Provide the model and artifacts as mounted read-only files at `/models/agrilens_model.tflite` and `/models/artifacts/`, and inject secrets from the platform's secret manager.

## Local Python setup

Use Linux x86_64 or ARM64 with CPython 3.11, supported by the available `tflite-runtime` wheel. Install `requirements.txt`, copy `.env.example` to `.env`, and set the Supabase URL/public anon key and Gemini key. `AGRILENS_MODEL_PATH` and `AGRILENS_ARTIFACTS_DIR` default to the existing local app model and training artifacts.

Run with `uvicorn --env-file .env app.main:app --host 0.0.0.0 --port 8000` from this directory. Flutter should call the service over HTTPS in deployed environments. Local HTTP is for development only.

The deployed service must be given `agrilens_model.tflite` and the three versioned contract files (`class_map.json`, `preprocess_contract.json`, `rejection_policy.json`). The Flutter model assets are git-ignored today, so they are not automatically present in a deployment checkout.

## API

- `GET /health`: process health only; it does not certify model readiness.
- `POST /auth/register`: JSON `{ "email": "...", "password": "..." }`; creates a Supabase Auth account. Whether a session is returned depends on Supabase email-confirmation settings.
- `POST /auth/login`: JSON `{ "email": "...", "password": "..." }`; returns the Supabase Auth session, including the access token Flutter sends as a bearer token to protected endpoints.
- `POST /v1/diagnoses`: multipart `image` upload; returns the typed prediction and score evidence.
- `POST /v1/answers`: JSON classifier evidence plus recent turns and optional follow-up; returns `{ "answer": ... }`.

Authenticated requests use `Authorization: Bearer <Supabase access token>`. The backend verifies the token with Supabase Auth. Apply `supabase/schema.sql` in the Supabase SQL editor to provision owner-scoped history, shop tables, RLS policies, and the private photo bucket. Flutter must call FastAPI only.

### Shop API

- `POST /v1/history/sync`: authenticated upsert of conversations, messages, and predictions. The server assigns the authenticated owner ID; message and prediction references are checked against that owner's saved records.
- `GET /v1/products`: authenticated list of active products.
- `POST /v1/products`: add a product using the `X-Shop-Admin-Token` header. Include optional `image_url` to download a product image into Supabase Storage.
- `DELETE /v1/products/{product_id}`: deactivate a product using the operator token. Existing order snapshots remain intact.
- `POST /v1/products/import`: import CSV using the operator token. Headers are `sku,name,description,price,currency,stock_quantity,crops,conditions`; separate crop and condition tags with `|`. An optional `image_url` column supplies an image per row. Existing SKUs are updated by import.
- `GET /v1/recommendations`: products matched to the authenticated user's scans and explicit crop or condition mentions in saved user messages, with a reason for each match.
- `POST /v1/orders`: create an order with `items` (`product_id`, `quantity`), `contact_name`, `phone`, and `delivery_address`. Stock is reserved transactionally. Orders containing multiple currencies are rejected.
- `GET /v1/orders`: list the authenticated user's orders with item snapshots.

Set `SUPABASE_SERVICE_ROLE_KEY` and a long random `SHOP_ADMIN_TOKEN` on the backend to enable catalog management. Keep both server-side; clients receive neither secret. Product images must be publicly reachable HTTPS JPEG, PNG, or WebP files under 5 MB. FastAPI validates the resolved host and redirects, uploads the original bytes to the public `agrilens-products` bucket, and stores the object path on the product. The shop image bucket is separate from private chat photos. Orders do not collect payment. `POST /v1/history/sync` supports record upserts; photo transfer and remote deletion are still separate work.

## Contract limits

The prototype-similarity rejection check is unavailable because the training artifacts contain no portable class prototypes. The response leaves `prototype_similarity` null and uses only calibrated confidence and margin. The service does not treat a healthy class as proof of plant health.
