# AgriLens goal

## Product intent

AgriLens helps a farmer photograph a maize or tomato leaf, see which **supported condition it resembles**, and understand a safe next step. The first useful release works on a phone without a network connection for image classification. It presents uncertain or unsupported images honestly. Build the local database and both model services before the Chat screen; Weather and Store can follow later.

This is decision support, not a definitive diagnosis. A healthy-class result does not prove a plant is healthy. The classifier does not determine severity, identify every disease, or prescribe chemicals.

## Primary user journey

1. Open Chat and take a photo or select one from the gallery.
2. Review the photo and, if needed, retake it. Explain how to capture a clear, well-lit leaf.
3. Run the classifier on-device. Show progress and allow recovery from a failed decode or inference.
4. Show the crop, possible condition, confidence or uncertainty state, and model limitations in plain language. Keep the photo next to its result.
5. Offer short, reviewed condition information and practical observation steps. When evidence is weak, ask for a better photo or local expert help instead of fabricating a diagnosis.
6. Let the farmer ask a follow-up question once the conversation layer is ready. The answer must distinguish the model's observation from verified guidance.
7. Save the conversation and result in the local database, with clear status for pending and failed work. Add sync status only if cloud sync is later approved.

## V1 scope

- Flutter Android and iOS app; Android is the first device validation target.
- One leaf image at a time. Supported crops: maize and tomato.
- The exact nine classes and output order are defined in `../agrilens-training/artifacts/class_map.json`: maize common rust, northern leaf blight, gray leaf spot, healthy; tomato bacterial spot, early blight, late blight, leaf mold, healthy.
- Run the existing `assets/models/agrilens_model.tflite` locally. Match `../agrilens-training/artifacts/preprocess_contract.json` exactly: 224 x 224 RGB, direct resize, values scaled to 0..1 then normalized with the recorded ImageNet mean and standard deviation. Confirm actual tensor shape, dtype, and output semantics before wiring UI.
- Use the trained output order, temperature, margin, and other available evidence to return `possible_match`, `uncertain`, or `unsupported_or_unclear`. The policy in `../agrilens-training/artifacts/rejection_policy.json` is a starting contract, not a substitute for implementation and field validation.
- Reviewed disease guidance is structured content keyed by the class identifier. A language model may explain it but cannot replace the classifier or invent treatment advice.
- Navigation retains Chat, Store, Weather, History, and bottom Settings. Store and Weather may remain honest placeholders while diagnosis is built.

## Success criteria

- On a representative Android phone in airplane mode, the user can choose or capture a valid image and receive an on-device result in Chat. Record actual latency, peak memory, app size, and supported devices before setting release thresholds.
- A checked integration test confirms Flutter preprocessing and class mapping match the exported model. Compare representative logits and embeddings with the training reference where available.
- A non-leaf image, poor image, ambiguous result, and unsupported condition have clear recovery paths. Do not show a confident disease claim simply because one of nine logits is highest.
- Every displayed disease statement is traceable to reviewed guidance. The UI uses “possible match” language and explains that healthy means no supported condition was recognized.
- Existing mobile and wide-screen navigation behavior, light/dark themes, and core widget tests remain intact.
- Field evaluation includes labeled real-world photos and unsupported inputs, with per-class errors and rejection behavior recorded. PlantVillage test accuracy alone is not a release gate.

## Current evidence and gaps (23 October 2026)

- The app has a themed responsive SidebarX shell. `lib/app/chat/views/chat_page.dart` is a placeholder; the shell currently displays page labels rather than the ChatPage widget.
- A TFLite asset and a Qwen GGUF asset are present. `lib/app/chat/services/local_llm_service.dart` is empty. The existence of these files does not establish working inference.
- Training artifacts report 99.1% held-out PlantVillage accuracy and 98.7% macro F1. These numbers measure the recorded dataset split, not field reliability.
- The field probe contains 15 photos without ground-truth labels; the unsupported-input probe had zero images. No device benchmark, model card, or PyTorch/TFLite comparison file is present in the current artifacts folder.
- The rejection policy mentions prototype similarity, but a portable class-prototype artifact is not present. Do not silently claim that check is active or use its threshold without the required data.
- `system_design.md` describes an earlier backend-first proposal. The trained model goal and available TFLite asset now support an offline classifier path. Hosted services remain a later design decision.

## Architecture boundaries

- Widgets present state and dispatch actions. A diagnosis service owns image decoding, preprocessing, model invocation, class mapping, and rejection. Use typed result and failure states; do not put tensor logic in widgets.
- The classifier supplies image evidence. Reviewed content supplies descriptions and next steps. A conversational model, if enabled, explains only within those boundaries and reports uncertainty faithfully.
- Keep user images local by default. Any server upload, account sync, analytics, or external LLM transfer needs a documented user-facing purpose and explicit product decision.
- Store model version, preprocessing version, class ID, decision state, score evidence, and timestamp with each saved result so old conversations remain interpretable after a model update.
- Build the local Drift database before connecting the models and Chat screen. Treat camera/gallery and network capabilities as replaceable services. Do not introduce a backend API merely because an old design note mentioned one.

## Out of scope for the first diagnosis milestone

Automatic treatment or pesticide prescriptions; severity or yield estimation; whole-field assessment; multi-leaf detection; disease classes outside the nine-class map; cloud accounts and sync; weather and commerce integrations; a general-purpose chatbot.

## Decisions reserved for the project owner

1. Whether the bundled GGUF model is suitable for released follow-up chat or a hosted model is needed. Start with a real local integration and compare device performance, offline needs, privacy, and answer quality before choosing the release path.
2. Whether and when accounts, Supabase, FastAPI, sync, Weather, and Store enter the product scope. Define their contracts before implementation.
3. Which agricultural sources and reviewer approve condition guidance, including region-specific treatment wording.
4. Release thresholds for field performance, rejection, supported devices, inference time, memory, and package size after measurement.
5. Data retention, backup, opt-in upload, and deletion behavior for photos and chat history.

## Related files

- `plan.md`: ordered work and acceptance gates.
- `AGENTS.md`: instructions for coding agents.
- `../agrilens-training/goal.txt` and `../agrilens-training/artifacts/`: model intent and exported contracts.
- `system_design.md`: useful earlier ideas; some deployment assumptions are superseded by this goal.
