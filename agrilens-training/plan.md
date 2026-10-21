I've built the first two notebooks, `00_environment_check.ipynb` and `01_dataset_audit_and_grouping.ipynb`. I couldn't run them here (no DirectML, no dataset), so I only syntax-checked the code cells. Expect to fix small things when you run them.

## Project layout

```
agrilens-classifier/
  notebooks/   00 … 08
  artifacts/   class_map.json, manifests, splits, weights, tflite, reports
  data/        PlantVillage (read-only), field_photos/, unsupported/
```

Run `00` and `01` with a kernel from your existing DirectML environment (`python -m ipykernel install --user --name agrilens-dml`). Neither notebook installs anything.

## Roadmap

| # | Notebook | Output |
|---|---|---|
| 00 | Environment check | CPU vs DirectML agreement, a real 9-class training step, timing, `env_report.json` |
| 01 | Dataset audit and grouping | Frozen class order, quality review, exact and near-duplicate groups, `manifest_v1.csv` |
| 02 | Final groups and splits | Embedding-based sibling merging, grouped stratified train/val/test, the resize policy |
| 03 | Head training | Frozen backbone, class-weighted loss or balanced sampling |
| 04 | Fine-tuning | Last blocks unfrozen at a lower learning rate, multiple seeds |
| 05 | Evaluation | Per-class precision/recall/F1, confusion matrix, then field photos |
| 06 | Rejection and calibration | Temperature scaling and the uncertainty mechanism |
| 07 | Export (separate environment) | `.tflite`, PyTorch vs TFLite comparison, `model_card.json` |
| 08 | Android benchmark | Latency, memory and size on a real phone |

## What the first two notebooks decide

- **Class order:** `01` writes `class_map.json` once. That index order is the model's output order, so never reorder it.
- **Preprocessing:** `00` fixes the ImageNet mean and std at 224×224. The resize policy (direct resize or centre-crop) is left open until `02`, and Flutter must match whatever is chosen.
- **Leakage:** `01` groups images by rotation- and flip-invariant perceptual hashes, plus exact SHA-1 duplicates. This misses the same leaf photographed from a different angle, so `02` adds an embedding-similarity pass before splitting.
- **Unsupported conditions:** `01` records the other PlantVillage folders (septoria, spider mites, target spot, curl virus, mosaic) and leaves them untouched. They become your unsupported-condition test set and calibration data for the rejection mechanism. They stay out of training.
- **PlantVillage shortcuts:** its backgrounds are uniform across classes, so a model can score well by learning background or lighting instead of the lesion. That is why field photos are mandatory in `05`, and why PlantVillage accuracy alone will look better than reality.
- **Smallest class:** maize gray leaf spot is the smallest class by a wide margin, so expect to handle imbalance in `03`.

## Design choices to settle early (built in `03` and `06`)

- **Rejection:** the model will return three things: the nine logits, a 576-dimensional embedding from before the classifier, and the app-side image-quality checks (blur, exposure, size). Rejection then combines a calibrated margin or max-logit with the embedding's distance to class prototypes. This catches unrelated inputs that softmax alone happily labels with high confidence.
- **Export:** the TFLite model should expose both the logits and the embedding as outputs so rejection runs on-device. I'll verify in `07` that `litert-torch` handles the two-output wrapper.
- **App states:** a prediction maps to one of `possible_match`, `uncertain` or `unsupported_or_unclear`, never a diagnosis. "Healthy" means no supported condition was recognised, and the UI should say so.
