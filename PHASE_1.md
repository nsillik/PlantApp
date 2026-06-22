# Phase 1 — Onboarding + Manual Plant Management

**Goal:** User can onboard (pick city), browse the 50-species catalog, add plants with placement info, and see personalized care sheets.

**Depends on:** Phase 0, Workstream A (catalog data — at least 10 species for development, 50 for release).

**Back in:** [PLAN.md](PLAN.md)

---

## Prerequisite Types

Before starting implementation, define these domain types that Phase 1 depends on:

- [x] `ClimateClassification` enum: temperate / tropical / arid (already defined in Phase 0)
- [x] `LightPlacement` enum: indirect / directSouth / directEastWest (already defined in Phase 0)
- [x] `HumidityPlacement` enum: dry / normal / wet (already defined in Phase 0)
- [x] `PlantName` struct — wraps `commonNamesLocalized: [String: String]` with a `localizedName` computed property that resolves to the current locale (falls back to `"en"`). Replaces the single `commonName: String` field in `PlantSpecies`.
- [x] `Season` enum: spring / summer / fall / winter. Derived from current month + hemisphere (inferred from latitude).
- [x] `CareSheet` struct — flat struct with six `String` fields: `water`, `light`, `soil`, `humidity`, `toxicity`, `commonProblems`. Each field holds personalized care *instructions*, not reference descriptions. Output of the merge function (step 1.9).
- [x] `CatalogService` protocol — `@Dependency` service with `func loadCatalog() async throws -> [PlantSpecies]`. Implementation reads from `Bundle.main` and caches in memory.

## Steps

### 1.1 UserProfile model + persistence
- [x] Domain model: `UserProfile` (city: String, latitude: Double, longitude: Double, climateClassification: ClimateClassification) — already defined
- [x] Repository: save/fetch the single user profile — already implemented (`UserProfileRepository` + `CoreDataUserProfileRepository`)
- [x] No further work needed.

**Acceptance:**
- Profile can be created, saved, loaded, and updated

### 1.2 Location onboarding step
- [x] City picker UI (text input with `CLGeocoder` suggestions)
- [x] On city selection: `CLGeocoder.geocodeAddressString` → lat/lon
- [x] Climate classification from latitude (>23.5° temperate, 15-30° arid, <15° tropical)
- [x] Write results into `UserProfile`

**Acceptance:**
- User types/selects a city; profile is populated with lat/lon + climate classification
- Geocoding handles errors (no results, network failure) with clear UI

### 1.3 OnboardingCoordinator
- [x] State machine: `.location` → `.addFirstPlant` → `.complete`
- [x] Persists `hasCompletedOnboarding` flag (UserDefaults)
- [x] First launch shows onboarding; subsequent launches skip to dashboard
- [x] Each step writes into shared `UserProfile` / triggers plant add flow

**Acceptance:**
- First launch flows: location → add first plant → dashboard
- Second launch skips onboarding
- Onboarding can be reset from settings (for testing)

### 1.4 Catalog data loading
- [x] Implement `CatalogService` protocol + bundled-JSON implementation
- [x] Decode `Resources/Catalog/catalog.json` → `[PlantSpecies]` via `CatalogService.loadCatalog()`
- [x] Validate all fields; handle missing/optional fields gracefully
- [x] Register `CatalogService` as a `@Dependency` key

**Acceptance:**
- All authored species (15 for dev, 50 for release) load from the bundle
- Data is complete per the schema; loading is fast (bundled, no network)
- In-memory cache avoids redundant reads on repeated calls

### 1.5 Catalog browse screen
- [x] Searchable list (by localized common name and scientific name)
- [x] Each row: thumbnail image, `PlantName.localizedName`, scientific name
- [x] Tapping a row → species detail card
- [x] Species detail: care parameters, growth habit, common issues, toxicity, images

**Acceptance:**
- User can search and browse all species in the catalog
- Detail screen shows all fields from the catalog entry
- Search is responsive (filtered as you type)
- Empty search results state

### 1.6 Add plant flow (from catalog)
- [x] From species detail: "Add this plant" button → AddPlantView
- [x] Placement fields:
  - Light: Indirect / Direct (south-facing) / Direct (east- or west-facing)
  - Humidity: Dry / Normal / Wet
- [x] Optional: custom name for the plant (defaults to species localized common name)
- [x] Save → creates `Plant` entity with species reference + placement

**Acceptance:**
- User can add a plant from the catalog with placement fields
- Plant persists in Core Data and appears in the plant list
- Placement uses the opinionated enum values (no freeform)

### 1.7 Plant list (dashboard)
- [x] List of user's plants: thumbnail, name, species, placement summary
- [x] Empty state: "Add your first plant"
- [x] Tap a plant → plant detail screen
- [x] "+" button to add another plant (catalog browse)
- [x] Settings gear button (top-left)

**Acceptance:**
- Added plants appear in the list
- Empty state shows when no plants exist
- Navigation to detail and add-plant works

### 1.8 Plant detail screen
- [x] Shows the generated care sheet (see 1.9–1.10)
- [x] Editable placement fields (changing them updates the care sheet live)
- [x] Shows species info (from catalog entry)
- [x] Shows plant name (editable)

**Acceptance:**
- Detail renders the care sheet for the specific plant
- Editing placement fields immediately updates the displayed care sheet
- Plant name is editable and persists

### 1.9 Care sheet merge function (pure logic)
- [x] Implement: `func generateCareSheet(species: PlantSpecies, user: UserProfile, light: LightPlacement, humidity: HumidityPlacement, season: Season) -> CareSheet`
- [x] Baseline: water interval from `PlantSpecies.wateringInterval`, adjusted by:
  - Placement light (south-facing → shorter interval, indirect → longer)
  - Placement humidity (dry → shorter interval, wet → longer)
  - Season (shorter days → longer interval in winter, shorter in summer; derived from latitude + month)
  - Climate classification (weak hint, not override)
- [x] `CareSheet` output — each field is personalized instructional text, not a static reference description:
  - `water:` e.g. "Water every 5–6 days" (not "Prefers moist soil")
  - `light:` e.g. "Your south-facing window is perfect" or "Current placement is too dim — move closer to a window"
  - `soil:` e.g. "Repot in well-draining mix" (mostly static from catalog)
  - `humidity:` e.g. "This dry room may cause brown tips — consider a pebble tray"
  - `toxicity:` static warning from catalog
  - `commonProblems:` filtered to issues likely given placement + season

**Acceptance:**
- Unit tests cover:
  - Baseline care sheet (no adjustments)
  - Each placement factor independently
  - Seasonal adjustment (winter vs. summer at a temperate latitude)
  - Combined factors
- Output is deterministic: same inputs → same `CareSheet`
- Works without any network or AI

### 1.10 Care sheet UI
- [x] Scrollable card with sections: Water, Light, Soil, Humidity, Toxicity, Common Problems
- [x] Each section renders content from the corresponding `CareSheet` field
- [x] Visual hierarchy: headers, body text, iconography

**Acceptance:**
- Care sheet renders all sections with adapted content
- Content reflects the merge function output (personalized to placement + season)
- Snapshot tests pass for at least two configurations (e.g., indirect-light/dry/winter vs. south-facing/normal/summer)

### 1.11 Settings screen
- [x] Edit location (re-runs geocoding, updates `UserProfile`)
- [x] Reset onboarding (for testing)
- [x] (Future: AI provider configuration — stubbed, not functional in Phase 1)

**Acceptance:**
- User can change city; climate classification updates
- All plant care sheets re-render with new climate on next view appearance
- Onboarding can be reset

---

## Phase 1 Exit Criteria

- [x] First-launch onboarding completes (city → add first plant → dashboard)
- [x] All catalog species (15 for dev, 50 for release target) are browsable and searchable
- [x] User can add a plant from the catalog with placement fields
- [x] Care sheet renders with personalized adjustments (placement + season + climate)
- [x] Placement fields are editable from plant detail; care sheet updates live
- [x] Location is editable from settings; care sheets re-render on next view appearance
- [x] Care sheet merge function has unit tests (7 test cases)
- [x] Snapshot tests pass for: catalog detail, care sheet (×2 configs), home (empty + loading)
- [x] All user-facing strings use `String(localized:)` (EN + ES in Localizable.xcstrings)
