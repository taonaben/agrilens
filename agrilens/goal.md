# AgriLens goal

## Product intent

AgriLens helps a farmer photograph a maize or tomato leaf, see which **supported condition it resembles**, and understand a safe next step. The app uses a FastAPI backend over HTTPS for image classification and hosted Gemini responses. Drift keeps a local copy of conversations and results; authenticated history sync uses Supabase Auth. The app needs a network connection to analyze images or ask follow-up questions, while saved local history remains available offline.

## Owner-approved architecture direction (24 October 2026)

- Move all image inference to FastAPI and use Gemini through that service for follow-up answers. Keep the Gemini credential on the server.
- Use Supabase Auth with email/password to identify the user for protected API requests and history sync. FastAPI mediates all client requests; Supabase Postgres is the persistent history store. Flutter must not connect directly to Supabase data services.
- Keep Drift as the local conversation store and cache. Sync conversations, messages, predictions, and original leaf photos through FastAPI to Supabase Postgres and a private Supabase Storage bucket.
- Retain synced photos with their conversation until that conversation is deleted. FastAPI mediates reads, writes, and deletion; Flutter must not call Supabase database or storage APIs directly.

This is decision support, not a definitive diagnosis. A healthy-class result does not prove a plant is healthy. The classifier does not determine severity, identify every disease, or prescribe chemicals.

## Primary user journey

1. Open Chat and take a photo or select one from the gallery.
2. Review the photo and, if needed, retake it. Explain how to capture a clear, well-lit leaf.
3. Upload the selected photo to FastAPI over HTTPS for classification. Show progress and allow recovery from network, decode, or inference failures.
4. Show the crop, possible condition, confidence or uncertainty state, and model limitations in plain language. Keep the photo next to its result.
5. Offer short, reviewed condition information and practical observation steps. When evidence is weak, ask for a better photo or local expert help instead of fabricating a diagnosis.
6. Let the farmer ask a follow-up question through FastAPI, which calls hosted Gemini. The answer must distinguish classifier evidence from verified guidance.
7. Save the conversation and result in Drift, with clear status for pending and failed work. Sync history and original photos to the authenticated account, and remove remote records and photos when a conversation is deleted.

## V1 scope

- Flutter Android and iOS app; Android is the first device validation target.
- One leaf image at a time. Supported crops: maize and tomato.
- The exact nine classes and output order are defined in `../agrilens-training/artifacts/class_map.json`: maize common rust, northern leaf blight, gray leaf spot, healthy; tomato bacterial spot, early blight, late blight, leaf mold, healthy.
- Run the existing `assets/models/agrilens_model.tflite` in FastAPI. Match `../agrilens-training/artifacts/preprocess_contract.json` exactly: 224 x 224 RGB, direct resize, values scaled to 0..1 then normalized with the recorded ImageNet mean and standard deviation. Confirm actual tensor shape, dtype, and output semantics before wiring the endpoint.
- Use the trained output order, temperature, margin, and other available evidence to return `possible_match`, `uncertain`, or `unsupported_or_unclear`. The policy in `../agrilens-training/artifacts/rejection_policy.json` is a starting contract, not a substitute for implementation and field validation.
- Reviewed disease guidance is structured content keyed by the class identifier. Gemini may explain it but cannot replace the classifier or invent treatment advice.
- Navigation retains Chat, Store, Weather, History, and bottom Settings. Store and Weather may remain honest placeholders while diagnosis is built.

## Success criteria

- On a representative Android phone with network access, the user can choose or capture a valid image and receive a server-side result in Chat. Record round-trip latency and supported devices before setting release thresholds.
- A checked integration test confirms Flutter preprocessing and class mapping match the exported model. Compare representative logits and embeddings with the training reference where available.
- A non-leaf image, poor image, ambiguous result, and unsupported condition have clear recovery paths. Do not show a confident disease claim simply because one of nine logits is highest.
- Every displayed disease statement is traceable to reviewed guidance. The UI uses “possible match” language and explains that healthy means no supported condition was recognized.
- Existing mobile and wide-screen navigation behavior, light/dark themes, and core widget tests remain intact.
- Field evaluation includes labeled real-world photos and unsupported inputs, with per-class errors and rejection behavior recorded. PlantVillage test accuracy alone is not a release gate.

## Current evidence and gaps (24 October 2026)

- The app has a themed responsive SidebarX shell, Drift-backed Chat flow, and local classifier/conversation services from the earlier implementation direction.
- The user has now selected FastAPI-hosted TFLite inference, Gemini responses, Supabase email/password Auth, and FastAPI-owned history storage. Flutter HTTPS adapters and the FastAPI inference/answer endpoints are being introduced; persistent history sync is not implemented yet.
- The model files under `assets/models/` are git-ignored. The Flutter app no longer bundles that directory; the backend deployment must be provisioned with the TFLite model separately. The Qwen GGUF is not part of the hosted path.
- Training artifacts report 99.1% held-out PlantVillage accuracy and 98.7% macro F1. These numbers measure the recorded dataset split, not field reliability.
- The field probe contains 15 photos without ground-truth labels; the unsupported-input probe had zero images. No device benchmark, model card, or PyTorch/TFLite comparison file is present in the current artifacts folder.
- The rejection policy mentions prototype similarity, but a portable class-prototype artifact is not present. Do not silently claim that check is active or use its threshold without the required data.
- `system_design.md` and the completed local-service work describe earlier alternatives. The owner-approved HTTPS backend direction in this document supersedes those runtime choices.

## Architecture boundaries

- Widgets present state and dispatch actions. A diagnosis service owns image decoding, preprocessing, model invocation, class mapping, and rejection. Use typed result and failure states; do not put tensor logic in widgets.
- The classifier supplies image evidence. Reviewed content supplies descriptions and next steps. A conversational model, if enabled, explains only within those boundaries and reports uncertainty faithfully.
- Upload a photo only when the user requests diagnosis. Retain the original in private remote storage as part of synced history until its conversation is deleted; mediate all access and deletion through FastAPI.
- Store model version, preprocessing version, class ID, decision state, score evidence, and timestamp with each saved result so old conversations remain interpretable after a model update.
- Keep Drift as the local database and make FastAPI, Supabase Auth, and network access replaceable services. Keep Gemini credentials and model execution on the backend.

## Out of scope for the first diagnosis milestone

Automatic treatment or pesticide prescriptions; severity or yield estimation; whole-field assessment; multi-leaf detection; disease classes outside the nine-class map; weather and commerce integrations; a general-purpose chatbot.

## Decisions reserved for the project owner

1. Define sync conflict behavior, offline deletion behavior, and account deletion semantics before shipping history sync. FastAPI, hosted Gemini, Supabase Auth, Supabase Postgres, private Supabase Storage for original photos, and conversation-scoped photo retention until conversation deletion are approved.
2. Which agricultural sources and reviewer approve condition guidance, including region-specific treatment wording.
3. Release thresholds for field performance, rejection, supported devices, inference time, memory, and package size after measurement.
4. Data retention and backup behavior for photos and chat history.

## Related files

- `plan.md`: ordered work and acceptance gates.
- `AGENTS.md`: instructions for coding agents.
- `../agrilens-training/goal.txt` and `../agrilens-training/artifacts/`: model intent and exported contracts.
- `system_design.md`: useful earlier ideas; some deployment assumptions are superseded by this goal.
