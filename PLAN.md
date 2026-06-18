# Verdigris — Implementation Plan

## Overview

This plan turns `VISION.md` into a sequenced build. The app is offline-first; the backend is Phase 2 (post-MVP, not covered here).

**MVP scope: Phases 0–3.** The MVP delivers the core loop: onboarding → add plants (browse or camera) → personalized care sheets → adaptive reminders → log care. Phase 3 (camera plant ID) is the hero feature and the portfolio centerpiece.

Phases 4–6 are post-MVP enrichment and are sketched below; their detailed `PHASE_N.md` plans will be written when we approach them.

**Monorepo layout.** This repo houses multiple components, each in a top-level directory:

| Directory | Component | Phase |
|---|---|---|
| `app/` | iOS app (Swift, SwiftUI, tuist) | MVP Phases 0–3 |
| `backend/` | REST API (Node, PostgreSQL, Redis) | Phase 2 (sketched below) |
| `data-pipeline/` | dbt analytics models | Phase 2 (sketched below) |

The root `.mise.toml` pins tool versions for the whole repo. The iOS app uses tuist (via mise) for project generation; backend and data-pipeline will use their own tooling when they're built.

## Long-Lead Workstreams (parallel, start in Phase 0)

These run alongside the phased work. They gate specific phases but don't block earlier ones.

### Workstream A — Bundled Plant Catalog
- **What:** ~50 common houseplants as a bundled JSON dataset (common/scientific names, care parameters, common issues, growth habits, image references).
- **Gates:** Phase 1 (catalog browse + care sheet merge).
- **Status:** Not started. Schema must be defined in Phase 0; data sourcing/authoring is content work.

### Workstream B — CoreML Models
- **What:** Two models — (B1) a plant *detector* for the real-time viewfinder (object detection), (B2) a species *classifier* for on-capture identification (image classification).
- **Gates:** Phase 3 (camera plant ID). Does not block Phases 0–2.
- **Status:** Not started. Approach (train vs. source vs. convert) must be decided in Phase 0. This is the longest-lead item in the MVP.

## Phases

### Phase 0 — Foundation → [PHASE_0.md](PHASE_0.md)

**Goal:** A building, tested, CI-green shell with all architectural plumbing in place.

**Depends on:** Nothing.

**Deliverables:**
- Tuist + mise project (`.mise.toml`, `Tuist.swift`, `Project.swift`, app target, iOS 26, App Group + CloudKit entitlements)
- SPM dependencies via tuist (swift-dependencies, SnapshotTesting)
- SwiftLint via mise
- Core Data schema + `NSPersistentCloudKitContainer`
- `PlantRepository` protocol + Core Data implementation
- Dependency graph (swift-dependencies)
- MVVM-`@Observable` skeleton proven with one screen
- SnapshotTesting proven with one test
- GitHub Actions CI (build + test + lint)
- Workstream A catalog schema defined; data work started
- Workstream B approach decided; model work started

**Acceptance criteria:**
- [ ] App builds and runs on iOS 26 simulator
- [ ] CI pipeline is green on push (build + test + lint)
- [ ] Core Data store loads; CRUD works through `PlantRepository`
- [ ] `@Dependency` injection works; mock injection verified in a test
- [ ] One snapshot test passes
- [ ] SwiftLint passes with no errors
- [ ] Catalog JSON schema is defined and documented
- [ ] CoreML model approach (train/source/convert) is documented

---

### Phase 1 — Onboarding + Manual Plant Management → [PHASE_1.md](PHASE_1.md)

**Goal:** User can onboard (pick city), browse the 50-species catalog, add plants with placement info, and see personalized care sheets.

**Depends on:** Phase 0, Workstream A (catalog data).

**Deliverables:**
- `UserProfile` model + location onboarding (CLGeocoder → lat/lon + climate classification)
- `OnboardingCoordinator` (location → add first plant)
- Bundled catalog loading (JSON → models)
- Catalog browse screen (search + list + detail)
- Add-plant flow (species → placement → save)
- Plant list (dashboard)
- Plant detail screen (care sheet + editable placement)
- Care sheet merge function: `(PlantProfile, UserProfile, Placement, Season) -> CareSheet`
- Care sheet UI (scrollable, adaptive sections)
- Settings screen (edit location)

**Acceptance criteria:**
- [ ] First-launch onboarding completes (city → add first plant)
- [ ] All 50 catalog species are browsable and searchable
- [ ] User can add a plant from the catalog with placement fields
- [ ] Care sheet renders with personalized adjustments based on placement + season + climate
- [ ] Placement fields are editable from plant detail; care sheet updates live
- [ ] Location is editable from settings; care sheets re-render
- [ ] Care sheet merge function has unit tests covering varied inputs
- [ ] Snapshot tests pass for catalog detail, plant detail, care sheet, onboarding
- [ ] All user-facing strings localized (EN + ES)

---

### Phase 2 — Scheduling, Reminders, Care Log → [PHASE_2.md](PHASE_2.md)

**Goal:** The app becomes daily-useful: adaptive reminders fire, user logs care with one tap, dashboard shows what's due.

**Depends on:** Phase 1.

**Deliverables:**
- `CareSchedule` model
- Scheduling engine (pure function: schedule + factors → next due dates)
- Care event logging (from dashboard + plant detail, with optional photo)
- Dashboard with due/upcoming tasks + quick-action buttons
- `UNNotificationRequest` registration with 64-cap prioritization strategy
- Notification re-registration on launch + schedule changes
- Per-plant care event history timeline
- Photo attachment for care events (PhotosPicker/camera, compressed JPEG, external binary storage)

**Acceptance criteria:**
- [ ] Scheduling engine produces correct next-due dates from all adjustment factors (season, placement, adherence)
- [ ] User can log care events (water/fertilize/prune/repot) from dashboard and plant detail
- [ ] Dashboard shows correct due and upcoming tasks across all plants
- [ ] Notifications fire at correct times; 64-cap prioritization strategy works at scale (tested with 20+ plants)
- [ ] Notifications re-register on app launch and after schedule changes
- [ ] Care event history shows logged events chronologically per plant
- [ ] User can attach a photo to a care event; photo persists and syncs via CloudKit
- [ ] Scheduling engine has comprehensive unit tests
- [ ] Snapshot tests pass for dashboard, care event history
- [ ] All user-facing strings localized (EN + ES)

→ **MVP candidate A (lean):** If Phase 3 slips due to CoreML, the app is already a useful product here.

---

### Phase 3 — Camera Plant ID → [PHASE_3.md](PHASE_3.md)

**Goal:** The hero feature — point the camera at a plant, get species ID + confidence, confirm or override, flow into the existing add-plant path.

**Depends on:** Phase 1 (add-plant flow, catalog, care sheet), Workstream B (CoreML models).

**Deliverables:**
- Camera permission + AVFoundation capture session
- Real-time plant detection via Vision + detector model (bounding box overlay)
- On-capture species classification via classifier model
- Classification result UI (species + confidence bar)
- Species confirmation / catalog search override
- Integration with existing add-plant flow (confirmed species → placement → save → care sheet)
- Loading states and graceful error handling (model unavailable → catalog fallback)

**Acceptance criteria:**
- [ ] Camera preview shows live viewfinder with plant detection bounding box at camera framerate
- [ ] Tapping shutter captures and classifies within ~2 seconds on Neural Engine
- [ ] Result shows species name + confidence bar
- [ ] User can confirm species or override via catalog search
- [ ] Confirmed species flows into existing add-plant → placement → care sheet path (no new add-plant code path)
- [ ] Works fully offline (no network needed for ID)
- [ ] Graceful fallback to catalog search if models fail or are unavailable
- [ ] Snapshot tests pass for result UI states (loading, success, low confidence, error)
- [ ] All user-facing strings localized (EN + ES)

→ **MVP candidate B (full):** This is the portfolio centerpiece — the feature the product pitch leads with.

---

### Phase 4 — Widget + Diagnosis Layer 1 *(post-MVP)*

**Goal:** Home-screen widget showing due tasks; offline problem diagnosis with Vision symptom detection + hand-authored rule tree.

**Depends on:** Phase 2 (scheduling), Workstream A (rule tree rides on catalog).

**Detailed plan:** `PHASE_4.md` (to be written when approaching this phase)

**Sketched deliverables:**
- WidgetKit: single-plant widget + dashboard widget (App Group + shared scheduling function)
- Vision symptom detection (color, texture, pattern → symptom categories)
- Hand-authored rule tree: `(species, symptom, severity) → [LikelyCause]` for 50 species
- Bundled care cards (one per species per issue) as JSON
- NLModel for text queries — **in/out decision needed before this phase starts**

---

### Phase 5 — Diagnosis Layer 2 + Growth Tracking *(post-MVP)*

**Goal:** Optional AI enrichment for diagnosis; photo journal with health scoring and milestone detection.

**Depends on:** Phase 4 (diagnosis plumbing) for AI half; growth tracking is independent.

**Detailed plan:** `PHASE_5.md` (to be written when approaching this phase)

**Sketched deliverables:**
- `AIDiagnosisProvider` protocol + `OpenAICompatibleProvider` + `MockProvider`
- Prompt template (injects plant profile, context, Layer 1 diagnosis)
- AI result display alongside Layer 1
- Photo journal (`JournalEntry` model, timeline UI)
- Health scoring (user-reported 1–5 + Vision-derived signal)
- Milestone detection (new leaf, bloom, repotting anniversary, growth spurt)

---

### Phase 6 — Environment & Long-Term Insights *(post-MVP)*

**Goal:** Weather-aware scheduling adjustments + seasonal nudges.

**Depends on:** Phase 2 (scheduling consumes seasonal factors).

**Detailed plan:** `PHASE_6.md` (to be written when approaching this phase)

**Sketched deliverables:**
- Open-Meteo weather fetch via `URLSession` + `BGTaskScheduler`
- `EnvironmentalReading` time series in Core Data
- Seasonal playbook: `(latitude_band, month) → care adjustments`
- "For You" dashboard card
- Optional weekly summary notification

## Cross-Cutting (every phase)

- **Testing:** Unit tests for pure logic, mock-based tests for ViewModels, snapshot tests for key screens, UI tests for critical flows.
- **Accessibility:** Dynamic Type, accessibility labels/hints, system colors, Dark Mode — built in as each feature lands.
- **Localization:** English + Spanish via `String(localized:)` — built in as each feature lands.
- **Core Data schema:** Grows incrementally per phase; migrations handled as needed.
