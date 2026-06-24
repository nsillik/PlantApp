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
    func classify(image: CGImage) async throws -> RawClassificationResult
    func resolveModelLabel(_ label: String) async -> PlantSpecies?
}
```

### Domain Models

```swift
struct DetectionResult: Sendable, Equatable {
    let boundingBoxes: [DetectedBoundingBox]
}

struct DetectedBoundingBox: Sendable, Equatable {
    let normalizedRect: CGRect
    let confidence: Double
}

struct RawClassificationResult: Sendable, Equatable {
    let topLabel: String
    let confidence: Double
    let alternatives: [AlternativeLabel]
}

struct AlternativeLabel: Sendable, Equatable {
    let label: String
    let confidence: Double
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

A pure function `resolveModelLabel(_:) async -> PlantSpecies?` on the service protocol handles mapping model output labels to catalog species IDs — it joins the bundled `model-labels.json` (modelLabel → catalogID) against `CatalogService` (catalogID → real `PlantSpecies` with care data). This is testable in isolation and decouples CoreML invocation from catalog resolution.

### CameraViewModel

`CameraViewModel` is `@Observable` and manages camera session lifecycle, permission state, detection pipeline, and classification lifecycle. It injects `@Dependency(\.plantIdentification)`.

### PlantCameraView vs. CameraView

Two camera constructs exist with deliberate naming:

- **`PlantCameraView`** (SwiftUI host) — the AI-assisted plant identification flow. It stacks `CameraPreviewView` (AVFoundation representable) with overlays: bounding boxes, hint text, classifying spinner, result card, error messages, and the permission-denied prompt. This is what the user sees when tapping "Identify with Camera."
- **`CameraPreviewView`** (UIViewRepresentable) — the shared AVFoundation preview layer. It owns the capture session, shutter button, cancel button, and frame-delegate plumbing. Both `PlantCameraView` (AI flow) and the future `CameraView` (care-event photo attachment) reuse this representable.
- **`CameraView`** (reserved name, not yet built) — a future simple photo-attach flow for care events (snap a picture to attach to a `CareEvent`). This will also use `CameraPreviewView` but have a different overlay stack (no detection, no result card, just a snapshot–save–dismiss UX).
- **`PlantCameraFlow`** (view modifier) — a `ViewModifier` that owns the full-screen cover for `PlantCameraView`, the subsequent `AddPlantView` sheet, and the dismiss-then-navigate sequencing. Callers invoke `.plantCameraAddFlow(isPresented:onSaved:)`. This is used by `HomeView`, `OnboardingRootView`, and `CatalogBrowseView` (anywhere that wants "open camera → confirm species → add plant" in one action). The `AddPlantView` re-identify path is intentionally NOT routed through this modifier — it keeps its own inline `fullScreenCover` because it already lives inside an `AddPlantView` and only needs a `PlantSpecies` back.

---

## Steps

### 3.1 Camera permission + AVFoundation setup
- [x] Add `NSCameraUsageDescription` to Info.plist (English + Spanish)
- [x] Add camera button to `AddPlantView` → presents `PlantCameraView`; also available in `.addFirstPlant` flow
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
- [x] Model not available (not in bundle / failed to load) → camera screen shows "ID unavailable, search catalog instead"
- [x] Classification fails (model error) → graceful message + catalog search fallback
- [x] Camera error (hardware unavailable) → message + cancel
- [x] No plant detected in frame (detector finds nothing) → "Point at a plant" hint, no bounding box
- [x] Multiple plants in frame → detect all, use the largest/most-central for classification

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
- [ ] — Verify `model-labels.json` is regenerated against the **real** catalog UUIDs. The copy shipped during Phase 3 development (`app/Resources/Catalog/model-labels.json`) contains two synthetic UUIDs and is only a placeholder for dev/test.

**Acceptance:**
- Both models are bundled and load successfully
- Detection runs at camera framerate (B1)
- Classification completes in ~1–2 seconds (B2)
- Model output maps to real catalog entries (no orphaned species IDs)

---

## Phase 3 Exit Criteria

- [x] Camera preview shows live viewfinder with plant detection bounding box at camera framerate
- [ ] Tapping shutter captures and classifies within ~2 seconds on Neural Engine *(blocked: no B2 model)*
- [x] Result shows species name + confidence bar + alternatives
- [x] User can confirm species or override via catalog search
- [x] Confirmed species flows into existing add-plant → placement → care sheet path
- [ ] Works fully offline (no network for ID) *(blocked: no B2 model)*
- [x] Graceful fallback to catalog search when models fail or are unavailable
- [ ] Both CoreML models (B1, B2) are bundled, load, and run on Neural Engine *(blocked: Workstream B)*
- [x] Snapshot tests pass for result card states (success, low confidence, error) and camera permission denied state — each driven by mocking `PlantIdentificationService` via `withDependencies`, no live camera or CoreML required
- [x] All user-facing strings localized (EN + ES)

→ **MVP candidate B (full):** This is the portfolio centerpiece.
