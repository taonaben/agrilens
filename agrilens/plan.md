# AgriLens implementation plan

Build from the foundation up. The first Chat screen must use real saved records and real model outputs. No hardcoded predictions, scripted assistant answers, or fake repositories in the running app.

Status: `[ ]` pending; `[x]` implemented and verified. Keep a phase pending when its asset exists but its behavior has not been exercised.

## Tonight's target

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

- [ ] Define the command and result contract for `analyzeImage(conversationId, image)` and `sendFollowUp(conversationId, text)`, including cancellation, retry, and error states.
- [ ] For an image: copy the chosen file into app-owned storage; save a pending user message; run the classifier; persist prediction and decision state; build constrained conversation context; generate and save the assistant response. Do not lose the prediction if generation fails.
- [ ] For follow-ups: load the prior saved prediction and relevant conversation context; answer from that evidence; persist user and assistant messages. If there is no prediction, say the app needs a photo rather than inventing one.
- [ ] Keep database writes and state transitions idempotent for retries. Make model loading, image decode, inference, generation, and storage errors distinct and recoverable.
- [ ] Verify the sequence with a real image and real models through the service layer before wiring Chat. Use deterministic test doubles only inside automated tests, never as a runtime fallback.

**Gate:** one service call produces linked, persisted user image, prediction, and assistant message, or a persisted and understandable failure state.

## 5. Build Chat on the working pipeline

- [ ] Replace the Chat placeholder inside the existing responsive SidebarX shell. Load the current conversation from Drift and observe new messages.
- [ ] Add camera/gallery selection, image preview/retake, text follow-up, progress, cancellation, and retry. Ask for permissions at the point of use.
- [ ] Render the actual saved image, decision state, possible condition, uncertainty wording, and assistant response. Keep “healthy” wording cautious.
- [ ] Populate History from saved conversations and restore a selected thread after restart. Preserve Chat/Store/Weather, Solar Icons, theme colors, and pinned Settings.
- [ ] Verify the complete flow on mobile and wide layouts, plus a real phone with airplane mode enabled.

**Gate:** a user can take or choose a photo, receive a real prediction and model response, leave the screen, and return to the saved conversation. No sample results appear in production.

## After tonight: quality and release work

- [ ] Create and review a versioned disease-guidance catalog with agricultural sources and regional wording. Keep chemical guidance out until approved.
- [ ] Build labeled field and unsupported-input evaluation sets; measure per-class performance and rejection behavior. The current 15-photo probe has no ground truth and the unsupported probe is empty.
- [ ] Record Android latency, memory, package size, supported devices, and model loading behavior. Agree on release thresholds from those measurements.
- [ ] Decide whether Supabase/FastAPI, auth, sync, Weather, and Store belong in the next release; specify contracts before implementation.

## Work allocation

Other coding agents can take bounded tasks such as Drift schema/repository, model tensor inspection, Flutter inference adapter, Chat components, and focused tests. The project owner reviews the schema contract, rejection behavior, LLM delivery choice, agricultural content, privacy, and release criteria. Each handoff must show real output or a precise blocker, the files changed, and the validation performed.
