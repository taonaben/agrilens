# Instructions for coding agents

Read `goal.md` and `plan.md` before starting. Inspect the current code and `git status` before editing. This repo contains active user work, including uncommitted model and chat assets. Preserve it.

## Mission and authority

Build the smallest complete, testable slice of AgriLens's maize/tomato leaf diagnosis flow. Follow the nine-class model contract in the sibling `agrilens-training/artifacts` directory. Treat `goal.md` as the product objective and `plan.md` as the work sequence. If those conflict with the current model artifacts or code, report the conflict and seek the owner's decision before changing the product contract.

Agents may handle scoped implementation, boilerplate, refactors, fixtures, and focused tests. Follow the foundation-first order in `plan.md`: Drift database, prediction model, conversational model, pipeline, then Chat UI. Do not use fake predictions or scripted responses in the running app; deterministic test doubles belong only in tests. Keep major choices with the project owner: model/rejection changes, local versus hosted LLM for release, backend and auth architecture, agricultural advice, privacy policy, release targets, and new product scope. Bring the owner concrete options and evidence, not speculative rewrites. Do not block routine code work on these decisions when an independent slice is available.

## Existing code boundaries

- Flutter/Dart lives under `lib/`; shared theme and controls under `lib/shared/`; app features under `lib/app/`.
- Preserve the responsive `SidebarX` shell in `lib/app/main/app.dart`. Keep the existing `AppColors` and `AppTheme`, use Solar Icons for new navigation icons, retain Chat/Store/Weather and History, and keep Settings pinned at the bottom. Extend main destinations through `_pages` rather than a second navigation system.
- `ChatPage` is a placeholder today. Connect it through the existing shell when implementing chat; do not create a parallel home screen.
- `system_design.md` is an earlier proposal. Do not assume its FastAPI-first or hosted LLM paths are implemented or approved. The classifier target is the on-device TFLite asset.
- Existing dependencies in `pubspec.yaml` are not proof of implemented features. `plan.md` now specifies Drift for the local database and investigation of `llamadart` for the bundled conversational model. Keep Supabase and Dio out of the core path until their roles and contracts are decided.

## Model contract

- Use the exact ordered IDs in `../agrilens-training/artifacts/class_map.json`; never alphabetize or hand-reorder them.
- Use `../agrilens-training/artifacts/preprocess_contract.json` for image input. Verify tensor layout and dtype against the actual `.tflite` model. Preserve the image orientation and handle decode failures.
- Identify model outputs by verified tensor shape/metadata, not assumed output index. The export notebook intends nine logits and a 576-element embedding. Confirm this on the actual file.
- Implement calibrated rejection only with artifacts and checks actually available. Prototype similarity requires portable prototypes; the threshold alone is insufficient. Record any temporarily unavailable check in code and the handoff.
- Keep raw scores separate from user-facing claims. “Healthy” and high softmax scores are not proof of plant health or field accuracy. Do not invent unsupported crop or disease labels.
- Never use the LLM as the image classifier. Do not generate unreviewed pesticide, dose, or treatment instructions.

## Implementation practice

- Define typed models for image, prediction, decision state, messages, and errors. Keep widgets free of model-specific tensor and storage logic.
- Make loading, empty, offline, uncertain, unsupported, permission-denied, and inference-failure states understandable and recoverable.
- Request camera/gallery permissions only when the user invokes those features. Keep photos local unless an approved feature explicitly sends them away.
- Use small, focused changes. Do not overwrite unrelated files, remove existing assets, or reformat whole files for a narrow task. Check `git diff` and `git status` before handing off.
- Add meaningful tests around class ordering, preprocessing, inference mapping/rejection, and the user journey as those features are built. For UI changes, inspect the rendered layout on mobile and wide screens when possible.
- On Windows, use `dart format` for Dart files. Run focused `flutter analyze`/`flutter test` checks; if a broad pre-existing failure occurs, report it separately from changes in the assigned slice. If the Flutter tool lock is stale, `FLUTTER_ALREADY_LOCKED=true` is available for focused validation.

## Handoff format

Report: what changed; exact files; commands/tests and results; any current limitation; and the next dependency or owner decision. Do not claim device inference, field accuracy, or end-to-end completion without direct evidence. Keep `plan.md` checkboxes aligned with completed and verified work only.
