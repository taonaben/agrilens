# Instructions for coding agents

Read `goal.md` and `plan.md` before starting. Inspect the current code and `git status` before editing. This repo contains active user work, including uncommitted model and chat assets. Preserve it.

## Mission and authority

Build the smallest complete, testable slice of AgriLens's maize/tomato leaf diagnosis flow. Follow the active versioned model contract; the training workspace defines the 34-class v2 taxonomy while the current nine-class v1 serving bundle remains active until v2 model artifacts are ready. Treat `goal.md` as the product objective and `plan.md` as the work sequence. The current Chat runtime is server-backed: FastAPI owns inference, answers, and conversation history; do not add offline history or sync unless the owner changes that direction.

Agents may handle scoped implementation, refactors, fixtures, and focused tests. Follow the current server-backed sequence in `plan.md`; earlier Drift/local-model work is historical and may remain for tests or reference, but must not run in Chat. Do not use fake predictions or scripted responses in the running app; deterministic test doubles belong only in tests. Keep major choices with the project owner: model/rejection changes, agricultural advice, privacy policy, release targets, and new product scope. Bring the owner concrete options and evidence, not speculative rewrites.

## Existing code boundaries

- Flutter/Dart lives under `lib/`; shared theme and controls under `lib/shared/`; app features under `lib/app/`.
- Preserve the responsive `SidebarX` shell in `lib/app/main/app.dart`. Keep the existing `AppColors` and `AppTheme`, use Solar Icons for new navigation icons, retain Chat/Store/Weather and History, and keep Settings pinned at the bottom. Extend main destinations through `_pages` rather than a second navigation system.
- `ChatPage` uses the existing responsive SidebarX shell. Extend it in place; do not create a parallel home screen.
- FastAPI runs the TFLite classifier and hosted Gemini. Flutter calls FastAPI over HTTPS with the Supabase Auth bearer token and never accesses Supabase database or storage APIs directly.
- Existing dependencies and earlier local services may remain for tests/reference, but Drift and local model services are not part of the Chat runtime. The backend's `README.md` documents current endpoints and setup.

## Model contract

- FastAPI uses the exact ordered IDs in `../agrilens-training/artifacts/class_map.json`; never alphabetize or hand-reorder them.
- The backend uses `preprocess_contract.json` and verifies tensor layout/dtype against the actual `.tflite` model. Preserve source image orientation and handle decode failures there.
- Backend outputs are identified by verified tensor shape/metadata, not assumed output index. Confirm outputs against the actual model.
- Implement calibrated rejection only with artifacts and checks actually available. Prototype similarity requires portable prototypes; the threshold alone is insufficient. Record any temporarily unavailable check in code and the handoff.
- Keep raw scores separate from user-facing claims. “Healthy” and high softmax scores are not proof of plant health or field accuracy. Do not invent unsupported crop or disease labels.
- Never use the LLM as the image classifier. Do not generate unreviewed pesticide, dose, or treatment instructions.

## Implementation practice

- Define typed models for image, prediction, decision state, messages, and errors. Keep widgets free of model-specific tensor and storage logic.
- Make loading, empty, network-failure, uncertain, unsupported, permission-denied, and inference-failure states understandable and recoverable. Chat requests require connectivity and are retryable; do not queue them offline.
- Request camera/gallery permissions only when the user invokes those features. Upload the selected original photo only for a requested diagnosis; the backend retains it with its conversation until deletion.
- Use small, focused changes. Do not overwrite unrelated files, remove existing assets, or reformat whole files for a narrow task. Check `git diff` and `git status` before handing off.
- Add meaningful tests around class ordering, preprocessing, inference mapping/rejection, and the user journey as those features are built. For UI changes, inspect the rendered layout on mobile and wide screens when possible.
- On Windows, use `dart format` for Dart files. Run focused `flutter analyze`/`flutter test` checks; if a broad pre-existing failure occurs, report it separately from changes in the assigned slice. If the Flutter tool lock is stale, `FLUTTER_ALREADY_LOCKED=true` is available for focused validation.

## Handoff format

Report: what changed; exact files; commands/tests and results; any current limitation; and the next dependency or owner decision. Do not claim device inference, field accuracy, or end-to-end completion without direct evidence. Keep `plan.md` checkboxes aligned with completed and verified work only.
