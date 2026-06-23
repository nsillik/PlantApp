# Phase 3 — Camera Plant ID

**Goal:** The hero feature — point the camera at a plant, get species ID + confidence, confirm or override, flow into the existing add-plant path.

**Depends on:** Phase 1 (add-plant flow, catalog, care sheet), Workstream B (CoreML models B1 + B2).

**Back in:** [PLAN.md](PLAN.md)

---

## Workstream B Dependency

This phase cannot start until Workstream B delivers:
- **B1 — Plant detector model:** A CoreML object-detection model that identifies plant-like shapes in a camera frame (not species-level). Integrated as `.mlmodelc` in the app bundle.
- **B2 — Species classifier model:** A CoreML image-classification model that identifies houseplant species from a captured image. Integrated as `.mlmodelc` in the app bundle.

If Workstream B is not complete, steps 3.2 and 3.3 are blocked. Steps 3.1, 3.4–3.7 can be developed with mock/stub models in the meantime.

---

## Architecture & Design

### PlantIdentificationService

Injected via `@Dependency(\.plantIdentification)`. Mock implementations are used during development until Workstream B completes.

```swift
protocol PlantIdentificationService: Sendable {
    func detectPlant(in pixelBuffer: CVPixelBuffer) async -> DetectionResult
    func classify(image: CGImage) async -> ClassificationResult
}
```

### Domain Models

```swift
struct DetectionResult: Sendable, Equatable {
    let boundingBox: CGRect
    let confidence: Double
}

struct ClassificationResult: Sendable, Equatable {
    let topMatch: PlantSpecies
    let confidence: Double
    let alternatives: [(species: PlantSpecies, confidence: Double)]
}
```

### Label-to-Catalog Mapping

A `model-labels.json` file is bundled alongside the `.mlmodelc`:

```json
{
  "labels": [
    { "modelLabel": "monstera_deliciosa", "catalogID": "A1B2C3D4-..." },
    { "modelLabel": "ficus_lyrata", "catalogID": "E5F6G7H8-..." }
  ]
}
```

A pure function `resolveModelLabel(_:) -> PlantSpecies?` on the service protocol handles mapping model output labels to catalog species IDs. This is testable in isolation and decouples CoreML invocation from catalog resolution.

### CameraViewModel

`CameraViewModel` is `@Observable` and manages camera session lifecycle, permission state, detection pipeline, and classification lifecycle. It injects `@Dependency(\.plantIdentification)`.

### CameraIdentificationView vs. CameraCaptureView

Phase 3 builds a new `CameraIdentificationView`. The existing `CameraCaptureView` from Phase 1 is a general-purpose photo capture utility and is not reused — the identification view needs real-time Vision overlays, detection state, and classification result handling that differ from the simple capture use case.

---

## Steps

### 3.1 Camera permission + AVFoundation setup
- [x] Add `NSCameraUsageDescription` to Info.plist (English + Spanish)
- [x] Add camera button to `AddPlantView` → presents `CameraIdentificationView`; also available in `.addFirstPlant` flow
- [x] Implement `CameraViewModel` (`@Observable`) managing session lifecycle, permission state, and capture
- [x] Implement camera capture session (`AVCaptureSession`, photo input, video preview)
- [x] Camera permission flow: request on first camera use, handle denied state
- [x] Camera UI: full-screen preview, shutter button, cancel button

**Acceptance:**
- Camera preview renders in-app at full frame rate
- Permission flow works (request → grant → preview; deny → explanatory state with link to settings)
- Shutter button is visible and tappable
- Camera can be launched from `AddPlantView` and the `.addFirstPlant` flow

### 3.2 Real-time plant detection (viewfinder)
*Blocked by Workstream B1.*
- [ ] Load B1 detector model into a `VNRecognizeObjectsRequest` (or `VNCoreMLRequest`) *(blocked: no B1 model yet)*
- [x] Run detection on each camera frame via `VNImageRequestHandler` (on a Vision queue, not main)
- [x] Map detected bounding boxes to preview coordinates (accounting for orientation/device)
- [x] Render bounding box overlay on the camera preview (SwiftUI overlay or `UIViewRepresentable`)
- [x] Throttle if needed to maintain preview framerate

**Acceptance:**
- Plant shapes are detected in real-time; bounding box appears over them
- Detection runs at camera framerate without dropping frames or janking the UI
- No species identification yet — just "plant here"
- Works in varied lighting (test with indoor conditions)

### 3.3 Species classification (on capture)
*Blocked by Workstream B2.*
- [x] On shutter tap: capture the current frame (`AVCapturePhotoOutput` or frame extraction)
- [x] Crop to the detected bounding box (if detection is active) or use full frame
- [ ] Run B2 classifier model on the captured image (Neural Engine) *(blocked: no B2 model yet)*
- [x] Show loading state (detected shape still highlighted, spinner)
- [x] Map classifier output to species (match classifier labels to catalog species IDs)
- [x] Return top result + confidence score + alternatives

**Acceptance:**
- Tapping shutter captures and classifies within ~2 seconds on Neural Engine
- Loading state shows during classification
- Result includes species name, confidence score (0–1), and top 3 alternatives
- Handles model failure gracefully (→ fallback to catalog search, step 3.5)

### 3.4 Classification result UI
- [x] Result card: species name, confidence bar, "Is this right?" prompt
- [x] "Confirm" button → proceeds to add-plant flow (step 3.6)
- [x] "Not quite" / "Search catalog" button → catalog search (step 3.5)
- [x] Low-confidence state: if confidence < threshold (e.g., 0.6), nudge toward catalog search
- [x] Show top alternatives as quick-select chips

**Acceptance:**
- Result card displays species + confidence clearly
- Confirm and override paths are obvious
- Low confidence triggers a gentle nudge to catalog search
- Alternative species are selectable in one tap

### 3.5 Species override / catalog search
- [x] Search interface (reuses catalog search from Phase 1.5)
- [x] User searches by common or scientific name
- [x] Selecting a species proceeds to add-plant flow (step 3.6)
- [x] "Back to camera" option to re-capture

**Acceptance:**
- User can search and select the correct species from the full catalog
- Flow connects to the existing add-plant path (no duplicate code)
- Re-capture returns to camera preview

### 3.6 Integration with add-plant flow
- [x] Confirmed/selected species → placement fields (Phase 1.6) → save → care sheet (Phase 1.9–1.10)
- [x] No new add-plant code path — reuses Phase 1 flow with species pre-filled
- [x] After save, navigate to plant detail (not back to camera)

**Acceptance:**
- Camera-identified plant flows through the same placement → save → care sheet path as catalog-added plants
- No duplicated add-plant logic
- User lands on plant detail after saving

### 3.7 Error handling + edge cases
- [ ] Model not available (not in bundle / failed to load) → camera screen shows "ID unavailable, search catalog instead"
- [ ] Classification fails (model error) → graceful message + catalog search fallback
- [ ] Camera error (hardware unavailable) → message + cancel
- [ ] No plant detected in frame (detector finds nothing) → "Point at a plant" hint, no bounding box
- [ ] Multiple plants in frame → detect all, use the largest/most-central for classification

**Acceptance:**
- Every error path has a clear user message and a path forward
- User is never stuck with a blank screen or unhandled error
- Catalog search is always available as a fallback

### 3.8 (Post-Workstream B) Model integration verification
- [ ] B1 detector model compiled to `.mlmodelc` and added to app bundle
- [ ] B2 classifier model compiled to `.mlmodelc` and added to app bundle
- [ ] Both models load without errors at runtime
- [ ] Both run on Neural Engine (not CPU) — verify via Instruments or timing
- [ ] Model labels map correctly to catalog species IDs (document the mapping)

**Acceptance:**
- Both models are bundled and load successfully
- Detection runs at camera framerate (B1)
- Classification completes in ~1–2 seconds (B2)
- Model output maps to real catalog entries (no orphaned species IDs)

---

## Phase 3 Exit Criteria

- [ ] Camera preview shows live viewfinder with plant detection bounding box at camera framerate
- [ ] Tapping shutter captures and classifies within ~2 seconds on Neural Engine
- [ ] Result shows species name + confidence bar + alternatives
- [ ] User can confirm species or override via catalog search
- [ ] Confirmed species flows into existing add-plant → placement → care sheet path
- [ ] Works fully offline (no network for ID)
- [ ] Graceful fallback to catalog search when models fail or are unavailable
- [ ] Both CoreML models (B1, B2) are bundled, load, and run on Neural Engine
- [ ] Snapshot tests pass for result card states (success, low confidence, error) and camera permission denied state — each driven by mocking `PlantIdentificationService` via `withDependencies`, no live camera or CoreML required
- [ ] All user-facing strings localized (EN + ES)

→ **MVP candidate B (full):** This is the portfolio centerpiece.
