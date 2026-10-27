I've built the first two notebooks, `00_environment_check.ipynb` and `01_dataset_audit_and_grouping.ipynb`. I couldn't run them here (no DirectML, no dataset), so I only syntax-checked the code cells. Expect to fix small things when you run them.

## Project layout

```
agrilens-classifier/
  notebooks/   00 … 08
  artifacts/   class_map.json, manifests, splits, weights, tflite, reports
  data/        source datasets (read-only), curated/ (34 folders), field_photos/, unsupported/
```

Run `00` and `01` with the GPU PC training environment. Notebook 01 reads the ordered 34-class map and expects a curated folder for each class. Preserve the currently active v1 model bundle until v2 training, calibration, and export are complete.

## Roadmap

| # | Notebook | Output |
|---|---|---|
| 00 | Environment check | CPU vs DirectML agreement, a real class-map-sized training step, timing, `env_report.json` |
| 01 | Dataset audit and grouping | Frozen class order, quality review, exact and near-duplicate groups, `manifest_v1.csv` |
| 02 | Final groups and splits | Embedding-based sibling merging, grouped stratified train/val/test, the resize policy |
| 03 | Head training | Frozen backbone, class-weighted loss or balanced sampling |
| 04 | Fine-tuning | Last blocks unfrozen at a lower learning rate, multiple seeds |
| 05 | Evaluation | Per-class precision/recall/F1, confusion matrix, then field photos |
| 06 | Rejection and calibration | Temperature scaling and the uncertainty mechanism |
| 07 | Export (separate environment) | `.tflite`, PyTorch vs TFLite comparison, `model_card.json` |
| 08 | Android benchmark | Latency, memory and size on a real phone |

## Existing preprocessing and data requirements

- **Class order:** The checked-in v2 `class_map.json` is authoritative for the training run. Its ID order is the model output order; never reorder it within a model version.
- **Preprocessing:** `00` fixes the ImageNet mean and std at 224×224. The resize policy (direct resize or centre-crop) is left open until `02`, and FastAPI preprocessing must match the exported `preprocess_contract.json`.
- **Leakage:** `01` groups images by rotation- and flip-invariant perceptual hashes, plus exact SHA-1 duplicates. This misses the same leaf photographed from a different angle, so `02` adds an embedding-similarity pass before splitting.
- **Unsupported conditions:** `01` records the other PlantVillage folders (septoria, spider mites, target spot, curl virus, mosaic) and leaves them untouched. Add them to the separate unsupported and field-photo sets for rejection evaluation; do not mix them into supported-class training.
- **Dataset shortcuts:** its backgrounds are uniform across classes, so a model can score well by learning background or lighting instead of the symptom or pest. That is why field photos are mandatory in `05`, and why source-dataset accuracy alone will look better than reality.
- **Smallest class:** class counts may vary substantially across the 34 crop-condition classes, so review per-class support and handle imbalance in `03`.

## Design choices to settle early (built in `03` and `06`)

- **Rejection:** the model will return three things: the class-count logits, a 576-dimensional embedding from before the classifier, and the app-side image-quality checks (blur, exposure, size). Rejection then combines a calibrated margin or max-logit with the embedding's distance to class prototypes. This catches unrelated inputs that softmax alone happily labels with high confidence.
- **Export:** the TFLite model should expose both the logits and the embedding as outputs so rejection runs on-device. I'll verify in `07` that `litert-torch` handles the two-output wrapper.
- **App states:** a prediction maps to one of `possible_match`, `uncertain` or `unsupported_or_unclear`, never a diagnosis. "Healthy" means no supported condition was recognised, and the UI should say so.
