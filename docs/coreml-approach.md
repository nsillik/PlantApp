# CoreML Model Approach (Workstream B)

## Overview

Phase 3 requires two CoreML models for camera-based plant identification:

- **B1: Plant Detector** — Real-time object detection model running via Vision at camera framerate. Purpose: detect plant-like shapes in the viewfinder and draw a bounding box.
- **B2: Species Classifier** — Image classification model running on captured frame. Purpose: identify the species of the detected plant.

## B1 — Plant Detector (Object Detection)

### Options Evaluated

| Approach | Description | Timeline Estimate | Effort | Verdict |
|---|---|---|---|---|
| **Create ML Training** | Use Create ML app to train an object detection model with a labeled dataset of plant photos | 2-4 weeks (data collection + labeling + training) | High | Fallback |
| **Existing CoreML Model** | Search for pre-trained plant detection CoreML models on developer.apple.com/machine-learning/models | 1-2 weeks (find + test) | Low | Preferred |
| **Model Conversion** | Convert a TensorFlow/PyTorch plant detection model (e.g., YOLO-based) to CoreML via coremltools | 1-3 weeks (model + conversion + optimization) | Medium | Secondary fallback |
| **Vision + CIImage Analysis** | Heuristic approach using Vision's built-in feature detection (no ML model — detect green-dominant regions, leaf-like edge patterns) | 1 week | Low | Interim/MVP-only |

### Chosen Approach: Existing CoreML Model (Primary) → Create ML Training (Fallback)

**Rationale:** Object detection for houseplants is a common enough task that pre-trained models exist. Apple's machine learning model registry or community models on Hugging Face should yield a suitable `.mlmodel`. If no suitable model is found within 2 weeks, fall back to training a custom model via Create ML.

**Next Steps:**
1. Search Apple ML models, Hugging Face, and GitHub for CoreML plant detection models
2. Download and test candidate models with sample houseplant photos
3. If none work: begin collecting a training dataset (~500 labeled images across 10+ species)

## B2 — Species Classifier (Image Classification)

### Options Evaluated

| Approach | Description | Timeline Estimate | Effort | Verdict |
|---|---|---|---|---|
| **Create ML Training** | Train an image classifier in Create ML with labeled species photos | 3-6 weeks (1,000+ images per species needed for good accuracy) | High | Required |
| **Existing CoreML Model** | Search for pre-trained plant species classifier | 1-2 weeks (find + test) | Low | Unlikely (species sets vary by region) |
| **Model Conversion** | Convert an existing model (e.g., PlantNet, iNaturalist models) to CoreML | 2-5 weeks (legal + technical) | Medium | Complex due to licensing |
| **On-Device Feature Extraction + Classification** | Use Vision's feature extraction (VNFeaturePrintObservation) on the captured image, then classify with a small kNN or SVM model | 2-3 weeks (feature extraction pipeline + training) | Medium | Interesting alternative |

### Chosen Approach: Create ML Training

**Rationale:** Species classification models are highly dependent on the specific set of species to identify. Since Verdigris targets ~50 common houseplants, a custom trained model is necessary for accurate classification. Pre-trained models won't match this specific species set.

**Data Requirements:**
- Minimum 200 images per species (1,000+ for good accuracy)
- Images should represent: various lighting conditions, angles, growth stages, and health states
- Dataset split: 80% training, 10% validation, 10% testing

**Next Steps:**
1. Begin collecting species images from public datasets (iNaturalist, PlantNet) and self-captured photos
2. Organize by species directory structure
3. Train initial model via Create ML with ~10 species
4. Evaluate accuracy; iterate with more data
5. Target: ~90% top-3 accuracy on held-out test set

## Dataset Sourcing

### Public Datasets

| Source | License | Species Coverage | Image Count | Notes |
|---|---|---|---|---|
| **iNaturalist** | CC-BY-NC | Global | Millions | Research-grade observations only; requires attribution |
| **PlantCLEF** | Varies | 10,000+ species | 300,000+ | Research dataset; verify license for commercial use |
| **LeafSnap** | Research only | 185 species | ~30,000 | US tree species only (not houseplants) |
| **Flavia** | Research | 32 species | ~2,000 | Limited species; Chinese plants |

**Verdict:** iNaturalist is the primary source for training data (CC-BY-NC, good houseplant coverage). Supplement with self-captured photos.

### Self-Captured Data

Team members will photograph houseplants at local nurseries, botanical gardens, and homes. Target: 50+ images per species for rare/common species that lack public dataset coverage.

## Timeline

| Milestone | Target Date | B1 Dependency | B2 Dependency |
|---|---|---|---|
| B1 model sourced/tested | Phase 1 midpoint | — | — |
| B2 training dataset complete (500+ images total) | Phase 1 midpoint | — | — |
| B2 initial model trained (10 species) | Phase 2 start | — | — |
| B2 final model trained (50 species, >90% top-3 accuracy) | Phase 3 start | — | B2 |
| Phase 3 implementation | Phase 3 | B1 | B2 |

## Licensing Summary

- **B1 model:** Ensure license permits distribution in a free app (Apache 2.0, MIT, or equivalent)
- **B2 training images:** CC-BY-NC from iNaturalist requires attribution in app; self-captured photos are owned by Verdigris
- **B2 model output:** The trained .mlmodel file is owned by Verdigris (no third-party licensing restrictions on the model itself)
