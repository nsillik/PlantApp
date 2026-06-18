# Phase 1 — Onboarding + Manual Plant Management

**Goal:** User can onboard (pick city), browse the 50-species catalog, add plants with placement info, and see personalized care sheets.

**Depends on:** Phase 0, Workstream A (catalog data — at least 10 species for development, 50 for release).

**Back in:** [PLAN.md](PLAN.md)

---

## Steps

### 1.1 UserProfile model + persistence
- [ ] Domain model: `UserProfile` (city: String, latitude: Double, longitude: Double, climateClassification: ClimateClassification)
- [ ] `ClimateClassification` enum: temperate / tropical / arid
- [ ] Repository: save/fetch the single user profile
- [ ] Core Data mapping (entity already in schema from Phase 0)

**Acceptance:**
- Profile can be created, saved, loaded, and updated
- Climate classification derives from geocoded latitude (see 1.2)

### 1.2 Location onboarding step
- [ ] City picker UI (text input with `CLGeocoder` suggestions, or a curated city list with free-text fallback)
- [ ] On city selection: `CLGeocoder.geocodeAddressString` → lat/lon
- [ ] Climate classification from latitude (e.g., >23.5° = tropical, refine bands as needed)
- [ ] Write results into `UserProfile`

**Acceptance:**
- User types/selects a city; profile is populated with lat/lon + climate classification
- Geocoding handles errors (no results, network failure) with clear UI

### 1.3 OnboardingCoordinator
- [ ] State machine: `.location` → `.addFirstPlant` → `.complete`
- [ ] Persists `hasCompletedOnboarding` flag (UserDefaults or Core Data)
- [ ] First launch shows onboarding; subsequent launches skip to dashboard
- [ ] Each step writes into shared `UserProfile` / triggers plant add flow

**Acceptance:**
- First launch flows: location → add first plant → dashboard
- Second launch skips onboarding
- Onboarding can be reset from settings (for testing)

### 1.4 Catalog data loading
- [ ] Load bundled JSON (`Resources/catalog.json` or similar) → `[PlantSpecies]` domain models
- [ ] Decode and validate all fields
- [ ] Handle missing/optional fields gracefully (image URLs may be optional during development)

**Acceptance:**
- All authored species (≥10 for dev, 50 for release) load from the bundle
- Data is complete per the schema defined in Phase 0
- Loading is fast (bundled, no network)

### 1.5 Catalog browse screen
- [ ] Searchable list (by common name and scientific name)
- [ ] Each row: thumbnail image, common name, scientific name
- [ ] Tapping a row → species detail card
- [ ] Species detail: care parameters, growth habit, common issues, toxicity, images

**Acceptance:**
- User can search and browse all species in the catalog
- Detail screen shows all fields from the catalog entry
- Search is responsive (filtered as you type)
- Empty search results state

### 1.6 Add plant flow (from catalog)
- [ ] From species detail: "Add this plant" button
- [ ] Placement fields:
  - Light: Indirect / Direct (south-facing) / Direct (east- or west-facing)
  - Humidity: Dry / Normal / Wet
- [ ] Optional: custom name for the plant (defaults to common name)
- [ ] Save → creates `Plant` entity with species reference + placement

**Acceptance:**
- User can add a plant from the catalog with placement fields
- Plant persists in Core Data and appears in the plant list
- Placement uses the opinionated enum values (no freeform)

### 1.7 Plant list (dashboard)
- [ ] List of user's plants: thumbnail, name, species, next task summary (placeholder text in Phase 1 — real scheduling in Phase 2)
- [ ] Empty state: "Add your first plant" with browse button
- [ ] Tap a plant → plant detail screen
- [ ] "+" button to add another plant (catalog browse)

**Acceptance:**
- Added plants appear in the list
- Empty state shows when no plants exist
- Navigation to detail and add-plant works

### 1.8 Plant detail screen
- [ ] Shows the generated care sheet (see 1.9–1.10)
- [ ] Editable placement fields (changing them updates the care sheet live)
- [ ] Shows species info (from catalog entry)
- [ ] Shows plant name (editable)

**Acceptance:**
- Detail renders the care sheet for the specific plant
- Editing placement fields immediately updates the displayed care sheet
- Plant name is editable and persists

### 1.9 Care sheet merge function (pure logic)
- [ ] Define domain types: `CareSheet` (sections: water, light, soil, humidity, toxicity, commonProblems)
- [ ] Implement: `func generateCareSheet(profile: PlantProfile, user: UserProfile, placement: Placement, season: Season) -> CareSheet`
- [ ] Baseline: water interval from `PlantProfile`, adjusted by:
  - Placement light (south-facing → shorter interval, indirect → longer)
  - Placement humidity (dry → shorter interval, wet → longer)
  - Season (shorter days → longer interval in winter, shorter in summer; derived from latitude + month)
  - Climate classification (weak hint, not override)
- [ ] Each section's text adapts to the inputs

**Acceptance:**
- Unit tests cover:
  - Baseline care sheet (no adjustments)
  - Each placement factor independently
  - Seasonal adjustment (winter vs. summer at a temperate latitude)
  - Combined factors
- Output is deterministic: same inputs → same `CareSheet`
- Works without any network or AI

### 1.10 Care sheet UI
- [ ] Scrollable card with sections: Water, Light, Soil, Humidity, Toxicity, Common Problems
- [ ] Each section renders content from the `CareSheet` model
- [ ] SwiftUI `ViewBuilder` / `ForEach` over sections (so sections can be reordered/added without touching navigation)
- [ ] Visual hierarchy: headers, body text, iconography

**Acceptance:**
- Care sheet renders all sections with adapted content
- Content reflects the merge function output (personalized to placement + season)
- Snapshot tests pass for at least two configurations (e.g., indirect-light/dry/winter vs. south-facing/normal/summer)

### 1.11 Settings screen
- [ ] Edit location (re-runs geocoding, updates `UserProfile`, care sheets re-render)
- [ ] Reset onboarding (for testing)
- [ ] (Future: AI provider configuration — stubbed, not functional in Phase 1)

**Acceptance:**
- User can change city; climate classification updates
- All plant care sheets re-render with new climate on next view appearance
- Onboarding can be reset

---

## Phase 1 Exit Criteria

- [ ] First-launch onboarding completes (city → add first plant → dashboard)
- [ ] All catalog species (≥10 for dev, 50 for release) are browsable and searchable
- [ ] User can add a plant from the catalog with placement fields
- [ ] Care sheet renders with personalized adjustments (placement + season + climate)
- [ ] Placement fields are editable from plant detail; care sheet updates live
- [ ] Location is editable from settings; care sheets re-render
- [ ] Care sheet merge function has unit tests
- [ ] Snapshot tests pass for: onboarding, catalog detail, plant detail, care sheet (×2 configs)
- [ ] All user-facing strings localized (EN + ES)
