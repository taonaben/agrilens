# AgriLens implementation plan

Build from the foundation up. The first Chat screen must use real saved records and real model outputs. No hardcoded predictions, scripted assistant answers, or fake repositories in the running app.

Status: `[ ]` pending; `[x]` implemented and verified. Keep a phase pending when its asset exists but its behavior has not been exercised.

## Owner-approved architecture update (24 October 2026)

The owner selected server-side predictions, hosted Gemini behind FastAPI, Supabase email/password Auth, Supabase Postgres history storage, and private Supabase Storage for original photos, all accessed through FastAPI. Drift remains the local history store. Synced photos are retained until conversation deletion. Flutter must not access Supabase database or storage APIs directly. This supersedes the earlier local-model release choice below. Existing local model and pipeline work remains useful for contract reference and rollback, but is not the selected runtime path.

### Migration sequence

1. [ ] Define a versioned HTTPS contract for diagnosis and follow-up responses using the exact nine-class order and current preprocessing/rejection artifacts.
2. [ ] Add a FastAPI service that loads the TFLite artifact, preprocesses images, applies available rejection checks, and calls Gemini only from the server. The Gemini key must never enter the Flutter app.
3. [ ] Add Supabase Auth token validation and ownership checks to protected endpoints. Persist original photos only as part of the authenticated conversation-history sync contract.
4. [ ] Replace the Flutter runtime model services with HTTPS implementations behind the existing service interfaces. Keep Drift local history usable offline and show network failures as retryable states.
5. [ ] Apply the Supabase Postgres schema and private Storage policies in `../backend/supabase/schema.sql`; FastAPI remains the client-facing API and uses the Supabase user token for owner-scoped access.
6. [ ] Define and implement authenticated snapshot sync, conflict handling, offline deletion tombstones, and photo upload/download/deletion through FastAPI. Keep local IDs stable and sync states explicit so failed work can resume safely.

### Migration gate

A photo reaches FastAPI over HTTPS, the service returns a typed prediction in trained class order and a bounded Gemini explanation, and Flutter persists both in Drift. Cross-device sync must preserve original photos and delete remote objects with their conversation.

## Original local implementation plan

The phases below describe the work completed under the previous local-first direction. Do not treat local model execution or airplane-mode diagnosis as the current release target.

## Historical local target

A **working local spine**: create a conversation in a database, select an image, run the bundled classifier, store the result, pass that result to the conversational model, save its response, and render the saved exchange in Chat. If device or model compatibility blocks a step, leave a visible error state and record the exact blocker; do not substitute fabricated output.

The database for this first pass is **on-device Drift/SQLite**, matching the offline classifier goal and the existing dependency. A hosted database, auth, and sync are separate decisions. Keep repository interfaces clean enough to add them later.

## 1. Define and build the local database

- [x] Define typed domain records and Drift tables for `conversations`, `messages`, and `predictions`. Use stable IDs, creation/update timestamps, and explicit schema versioning.
- [x] `messages` records conversation ID, role, content type, text, optional local image path, lifecycle state (`pending`, `complete`, `failed`), and timestamp. Store images as app-owned files referenced by path, not image blobs in SQLite.
- [x] `predictions` records its source message ID, crop/class ID, model and preprocessing versions, calibrated score evidence, decision state, failure reason when applicable, and timestamp. Preserve enough data to interpret a result after a model update.
- [x] Add repositories for creating/loading a conversation, appending messages, attaching a prediction, updating lifecycle state, and listing recent conversations. Use transactions for related writes and define image-file cleanup when a conversation is deleted.
- [x] Verify create/read/restart behavior, ordering, migrations, and failure recovery with a focused database test.

**Gate:** a real conversation and its image reference survive app restart. No Chat UI is required to prove this; a focused integration or repository test is enough.

## 2. Set up the prediction model

- [x] Inspect `assets/models/agrilens_model.tflite` input/output tensors. Verify tensor layout, dtype, the nine-logit output, and the embedding output against the export notebook.
- [x] Package the exact ordered class map and preprocessing contract from `../agrilens-training/artifacts/`. Implement 224 x 224 RGB direct resize and recorded normalization, including image orientation and decode errors.
- [x] Load, run, and dispose the on-device interpreter through a diagnosis service. Keep inference off the UI thread where feasible.
- [x] Apply available calibration and rejection checks. The prototype threshold cannot run until actual class prototypes are exported; make that limitation explicit. Return `possible_match`, `uncertain`, or `unsupported_or_unclear` with model evidence.
- [ ] Compare representative TFLite outputs with the PyTorch reference when available. Test class order, preprocessing, failure paths, and a real image on an Android device in airplane mode.

**Gate:** the service returns a real, typed result from the bundled model. A highest-scoring class alone is not treated as a confirmed disease.
**Partial:** Service code and unit tests are complete. Device inference test on Android hardware still required.

## 3. Set up the conversational model

- [x] Inspect the bundled `Qwen3-0.6B-Q8_0.gguf` asset, `llamadart` compatibility, supported devices, memory use, load time, and response speed. The empty `local_llm_service.dart` is a starting file, not an implementation.
- [x] Implement a small conversation service with explicit load, generate, cancel, error, and dispose behavior. Limit context and output length to fit the phone.
- [x] Give the model the saved prediction state and reviewed condition facts, not raw authority to diagnose an image. If reviewed guidance is not ready, limit the first prompt to accurately restating the classifier result and uncertainty; do not generate treatment advice.
- [ ] Exercise real generation on a target phone and save representative observed output for review. If the bundled model cannot run acceptably, report measured constraints before choosing a hosted fallback.

**Gate:** a real model produces a response from real prediction context; failure is reported honestly. **Owner decision:** whether local generation quality and device cost are acceptable for release, or whether a hosted model is needed.
**Partial:** Service code complete. On-device test required; latency and quality report needed before owner can decide on release path.

## 4. Define and implement the pipeline

- [x] Define the command and result contract for `analyzeImage(conversationId, image)` and `sendFollowUp(conversationId, text)`, including cancellation, retry, and error states.
- [x] For an image: copy the chosen file into app-owned storage; save a pending user message; run the classifier; persist prediction and decision state; build constrained conversation context; generate and save the assistant response. Do not lose the prediction if generation fails.
- [x] For follow-ups: load the prior saved prediction and relevant conversation context; answer from that evidence; persist user and assistant messages. If there is no prediction, say the app needs a photo rather than inventing one.
- [x] Keep database writes and state transitions idempotent for retries. Make model loading, image decode, inference, generation, and storage errors distinct and recoverable.
- [ ] Verify the sequence with a real image and real models through the service layer before wiring Chat. Use deterministic test doubles only inside automated tests, never as a runtime fallback.

**Gate:** one service call produces linked, persisted user image, prediction, and assistant message, or a persisted and understandable failure state.
**Partial:** Service-layer pipeline logic is implemented and verified with focused automated tests. Real-image and real-model service-layer verification is still pending.

## 5. Build Chat on the working pipeline

- [x] Replace the Chat placeholder inside the existing responsive SidebarX shell. Load the current conversation from Drift and observe new messages.
- [x] Add camera/gallery selection, image preview/retake, text follow-up, progress, cancellation, and retry. Ask for permissions at the point of use.
- [x] Render the actual saved image, decision state, possible condition, uncertainty wording, and assistant response. Keep “healthy” wording cautious.
- [x] Populate History from saved conversations and restore a selected thread after restart. Preserve Chat/Store/Weather, Solar Icons, theme colors, and pinned Settings.
- [ ] Verify the complete flow on mobile and wide layouts, plus a real phone with airplane mode enabled.

**Gate:** a user can take or choose a photo, receive a real prediction and model response, leave the screen, and return to the saved conversation. No sample results appear in production.
**Partial:** Desktop/static verification is complete for shell integration and pipeline-backed chat behavior. Real device verification (mobile + airplane mode) remains pending.

## Quality and release work

- [ ] Create and review a versioned disease-guidance catalog with agricultural sources and regional wording. Keep chemical guidance out until approved.
- [ ] Build labeled field and unsupported-input evaluation sets; measure per-class performance and rejection behavior. The current 15-photo probe has no ground truth and the unsupported probe is empty.
- [ ] Record server round-trip latency, backend inference time, Gemini response time, request limits, supported devices, and release thresholds.

## Work allocation

Bounded tasks include FastAPI inference, Gemini integration, Supabase Auth verification, Flutter HTTPS adapters, and Drift synchronization. The project owner reviews the schema contract, rejection behavior, remote storage and retention, agricultural content, privacy, and release criteria. Each handoff must show real output or a precise blocker, the files changed, and the validation performed.
