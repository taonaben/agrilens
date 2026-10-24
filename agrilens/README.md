# agrilens

A Flutter client for maize and tomato leaf decision support.

## Getting started

Install Flutter and follow the [Flutter documentation](https://docs.flutter.dev/) to run the app.

## Hosted diagnosis setup

Copy `.env.example` to `.env` and set:

- `AGRILENS_API_BASE_URL`: the FastAPI service URL. Use HTTPS for deployed environments. For an Android emulator, local development can use `http://10.0.2.2:8000`.
- `SUPABASE_URL` and `SUPABASE_ANON_KEY`: public Supabase Auth configuration. Do not add a service-role key or Gemini key to the Flutter app.

The app requires an email/password Supabase account to call the authenticated API. The FastAPI service configuration is in [the repository backend folder](../backend/README.md). Set `GEMINI_API_KEY` only in the backend environment.

## Current backend scope

FastAPI provides authenticated diagnosis and Gemini answer endpoints. The approved history design uses Supabase Postgres and a private Supabase Storage bucket for original photos, with FastAPI as the only client-facing data API. Apply `../backend/supabase/schema.sql` to provision the initial tables, RLS policies, deletion tombstones, and bucket. FastAPI history/sync/photo endpoints and Drift synchronization are not implemented yet; the diagnosis endpoint currently processes uploads in memory without retaining them.
