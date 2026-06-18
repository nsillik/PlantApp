# Verdigris (working title) — AI Plant Care Assistant

**Deployment target:** iOS 26+.

## Overview

Verdigris is an iOS app that helps people care for their houseplants. Point your camera at a plant, and the app identifies it, builds a personalized care plan, sends adaptive reminders, and helps you diagnose problems before your plants die. The app is houseplants-only — no outdoor plants, no garden plots, no frost-date reasoning.

This document connects what users see and do with the technical decisions that make those experiences possible. It's organized by user flow, not by architecture layer. It's a vision, not a spec: details will sharpen as we build.

---

## 1. Quick Start & Setup

### What the user experiences

A new user opens the app for the first time. They pick their city or region and add their first plant — either by snapping a photo or browsing a catalog of common houseplants. From that moment, the app knows who they are, where they live, and what they're growing.

### How it works technically

**Onboarding state machine.** A dedicated `OnboardingCoordinator` manages a sequence of screens (location → first plant). Each step writes into a shared `UserProfile` model that other features read from. This model is the single source of truth for personalization throughout the app. Location can be changed later from a settings/profile screen; it's a first-class editable field, not a one-shot onboarding answer.

**Location inference.** The app uses `CLGeocoder` to geocode the user's selected city into latitude (for daylight-hour calculations) and a rough climate classification (temperate/tropical/arid). This classification is only a weak proxy for indoor conditions — indoor humidity and temperature are dominated by heating, AC, and room placement, not outdoor climate — so it's used as a hint, not a driver. USDA hardiness zones aren't used — they're designed for outdoor perennials, and houseplants live indoors where frost dates are irrelevant. What matters for indoor plants is photoperiod (which drives seasonal watering adjustments) and what the user reports about their room (see per-plant placement, below). No location tracking after onboarding — the city selection is static unless the user moves and updates it in settings.

**Catalog of plants.** A bundled JSON dataset covers ~50 of the most common houseplants (monstera, pothos, snake plant, fiddle leaf fig, etc.). Each entry includes:

- Common and scientific names
- Care parameters (light needs, watering interval, soil type, humidity range, toxicity)
- Common issues and symptoms
- Growth habits (trailing, upright, climbing)
- Image references for visual ID matching

This dataset is small enough to version with the app and update via CloudKit pushes. It also serves as the fallback knowledge base when no AI endpoint is available.

**Per-plant placement.** When a user adds a plant (from the catalog or via photo ID), they record where it lives in their home. This is a small, opinionated set of fields rather than a freeform survey:

- **Light:** Indirect / Direct (south-facing) / Direct (east- or west-facing)
- **Humidity:** Dry / Normal / Wet

These two fields drive most of the personalized adjustments in the care sheet and scheduler (see sections 2 and 3). They're editable from the plant's detail screen at any time.

**Architecture plumbing.** Onboarding is the first consumer of the app's dependency graph. Services for networking, persistence, and AI are registered at launch via PointFree's `swift-dependencies` library (`@Dependency` property wrapper). During onboarding, only local services are active — no network calls are required to get started.

---

## 2. Plant ID & Care Basics

### What the user experiences

The user taps a camera button and points their phone at a plant. A bounding box highlights the plant in the viewfinder. The user taps the shutter, and within a second or two the species name appears with a confidence score, followed by a personalized care sheet: how much light it needs, when to water it, what soil to use, whether it's toxic to pets, and how to adjust care based on the user's home conditions (e.g., "Your apartment gets low light — water every 10–14 days instead of 7").

### How it works technically

**Two-phase plant ID: detection then classification.** Real-time species-level classification from a live viewfinder isn't practical on device — classification models are too heavy to run at 30fps. Instead, the camera view uses a two-phase approach:

1. **Detection (real-time):** A CoreML object-detection model runs via `VNRecognizeObjectsRequest` (Vision) on each frame to detect plant-like shapes and highlights them with a bounding box. This is lightweight and runs at camera framerate. No species identification yet — just "there's a plant here." Vision ships no built-in "plant detector," so this model must be either trained (Create ML's object-detection template, with a labeled photo set) or sourced from an existing CoreML plant-detection model. Sourcing/training this detector is a discrete, scoped piece of work called out here.
2. **Classification (on capture):** When the user taps the shutter, Vision captures the current frame and runs a species classification CoreML model on it. This takes ~1–2 seconds on the Neural Engine, no network needed. The UI shows a loading state with the detected shape still highlighted, then transitions to the result with a confidence bar.

The user can confirm the species or override it with a search of the bundled catalog. This split keeps the viewfinder responsive while still delivering accurate species identification.

**Personalized care sheet.** Once a species is identified, the app generates a care sheet by merging:

1. The static plant entry from the bundled catalog (base care parameters)
2. The user's climate classification and photoperiod (from onboarding)
3. The per-plant placement (light exposure + reported humidity; see section 1)
4. Seasonal adjustments (current month + latitude → day length)

For example, the base entry says "water every 7 days," but the plant's placement says "dry room, south-facing window" → the app adjusts to "water every 5–6 days in summer, every 10–12 days in winter." The exact multipliers for combining these factors will need data engineering work to tune; the merge itself is the deterministic part.

This merging logic is a pure function: `(PlantProfile, UserProfile, Placement, Season) -> CareSheet`. It's deterministic, testable, and works without any AI.

**Adaptive care guides.** The care sheet is rendered as a visual, scrollable card with sections (Water, Light, Soil, Humidity, Toxicity, Common Problems). Each section adapts its content based on the user's profile and season. The layout uses SwiftUI's `ViewBuilder` pattern so sections can be added, removed, or reordered without touching navigation logic.

---

## 3. Smart Reminders & Daily Care

### What the user experiences

The user receives gentle, context-aware notifications: "Time to water your Monstera" or "It's been 3 months — consider fertilizing your Pothos." The timing adjusts automatically for the season, local weather, and how reliably the user follows through. From the notification or the dashboard, the user taps "Watered," "Fed," or "Pruned" with a single tap, optionally adding a photo.

### How it works technically

**Adaptive scheduling engine.** Each plant has a `CareSchedule` that tracks:

- Last care event per type (watered, fertilized, pruned, repotted)
- Recommended interval (from the care sheet)
- Adjustment factors: current season, recent weather (if available), user's historical adherence

The scheduler is a deterministic algorithm, not an AI. It runs whenever the app is foregrounded and after each care event is logged, and the same algorithm also runs in the widget's timeline provider (section: WidgetKit) so the widget can render due tasks without launching the app. Both call sites compute from the same inputs and produce the same result — there's one scheduling function, two invocation points.

Example adjustment: if the user consistently waters their snake plant 2 days late, the scheduler extends the recommendation by 1 day.

**Notification infrastructure.** Reminders use `UNNotificationRequest` with calendar triggers. The app registers the next N due dates (e.g., next 5 watering reminders per plant) when the schedule changes, and re-registers on app launch. This avoids background processing while keeping reminders reliable. Note: iOS caps scheduled local notifications at 64 per app, so registering "next 5 per plant × multiple care types" overflows quickly as the plant collection grows. The registration strategy will need to prioritize (e.g., only the soonest reminder per plant, with the rest re-registered as earlier ones fire) — a technical solution to design before this scales.

WidgetKit provides a dashboard widget showing today's due tasks. The widget timeline is calculated from the same scheduling engine.

**Quick care log.** The dashboard and notification actions use `AppIntents` to log care events without opening the app. Each event is a `CareEvent` model (plant ID, event type, timestamp, optional progress photo) stored in Core Data.

If the user chooses to add a photo, the app presents a `PhotosPicker` to select an existing image or the camera for a new one. Photos are stored as compressed JPEGs in Core Data using `allowsExternalBinaryDataStorage` on the photo attribute, so Core Data manages the files and `NSPersistentCloudKitContainer` syncs them alongside the rest of the store.

---

## 4. Problem Diagnosis & AI Coaching

### What the user experiences

A leaf turns yellow. The user taps "What's Wrong?", snaps a photo, and the app identifies the likely cause — overwatering, nutrient deficiency, pest infestation, or light burn — with clear, step-by-step recovery instructions. The user can also type natural-language questions: "Why are my monstera leaves curling?" or "Can I move this plant near the AC?"

### How it works technically

**Dual-layer AI architecture.**

This is the app's most technically interesting feature, and the one that best demonstrates architectural thinking. The diagnosis system has two layers:

```
User input (photo or text question)
           │
           ▼
┌─────────────────────┐
│  Layer 1: On-device │  ◄── Always runs, no network
│  ─────────────────  │
│  • Vision: symptom  │
│    detection (color, │
│    texture, pattern) │
│  • Rule engine:     │
│    symptom + species │
│    → likely causes  │
│  • NL keyword match │
│    for text queries │
└─────────┬───────────┘
          │ produces initial diagnosis
          ▼
┌──────────────────────┐
│  Layer 2: AI (optional) │  ◄── If provider configured
│  ──────────────────── │
│  • Protocol-based    │
│  • Configured at     │
│    runtime / build   │
│  • One OpenAI-       │
│    compatible        │
│    endpoint (OpenAI, │
│    LM Studio, Ollama,│
│    etc. — swappable  │
│    at build time)    │
│  • Mock (testing)    │
│  • Prompt template   │
│    injects plant     │
│    profile + context │
└─────────┬────────────┘
          │ enriches or replaces Layer 1
          ▼
     Final diagnosis
     + recovery steps
```

**Layer 1: On-device (always works, free).**

- **Visual diagnosis:** Vision analyzes the photo for color anomalies (yellow, brown, spotted), texture (crispy, mushy), and patterns (streaks, stippling). These visual features map to symptom categories.
- **Rule engine:** A decision tree maps `(species, symptom_category, severity) → [LikelyCause]`. For example: `(Monstera, yellowing_lower_leaves, mild) → [overwatering, nitrogen_deficiency]`. The rule tree is hand-authored for the 50 bundled species and covers the most common issues.
- **Text queries:** NaturalLanguage framework's `NLModel` (trained on a small corpus of plant care Q&A) classifies the intent, then keyword extraction maps to symptom categories. For unrecognized queries, the app returns a polite "I'm not sure — here's what I found in the care guide" fallback. Note: training this `NLModel` is a deep piece of work — corpus collection, labeling, and `.mlmodel` generation are a scoped subproject, not a one-day task.

Layer 1 produces a diagnosis with confidence scores and care card references. The rule tree is bounded and curated, so its output is constrained to a known set of causes and recommendations.

**Layer 2: AI enrichment (optional, configurable).**

If the user has configured an AI provider, Layer 2 receives the Layer 1 diagnosis and enriches it:

- The photo and/or question are sent to the provider with a prompt template that injects:
  - The plant's species and current care schedule
  - The user's climate classification and per-plant placement
  - The Layer 1 diagnosis (included as context)
- The provider returns a natural-language assessment with recovery steps.
- The app displays the AI result alongside the Layer 1 diagnosis, clearly labeled.

How strongly the Layer 1 diagnosis should steer the Layer 2 output (context vs. constraint, whether to permit contradiction, how to surface disagreement) is a prompt-engineering question to settle with proper evals rather than a fixed design decision upfront.

The AI provider is abstracted behind a protocol:

```swift
protocol AIDiagnosisProvider {
    func diagnose(photo: Data, plantProfile: PlantProfile, context: DiagnosisContext) async throws -> AIDiagnosis
    func query(question: String, plantProfile: PlantProfile, context: DiagnosisContext) async throws -> AIResponse
}
```

Concrete implementations:
- `OpenAICompatibleProvider` (works with OpenAI, LM Studio, Ollama — any OpenAI-compatible API; which one is an implementation detail swappable at build time)
- `OnDeviceProvider` (always available, Layer 1 only)
- `MockProvider` (for SwiftUI previews and unit tests)

**Fallback and caching.** When no AI provider is configured, the app shows the Layer 1 diagnosis plus a subtle note: "Configure an AI provider for more detailed answers." When the AI provider is unreachable or slow, the app times out gracefully and shows the Layer 1 diagnosis with a note that AI enrichment is temporarily unavailable.

Care cards for common issues (one per species per issue) are bundled as JSON and rendered as static SwiftUI views. These load instantly and serve as the baseline educational content.

**Why this architecture works for a portfolio.**
- Demonstrates protocol-oriented design and dependency injection.
- Makes testing straightforward: test the rule engine with unit tests, test the AI integration with mocks.
- Showcases Apple frameworks (Vision, CoreML, NaturalLanguage) while also showing backend/AI integration skills.
- Every deployment of the app works fully (Layer 1), or optionally better (Layer 2). No broken experiences.
- The AI layer is entirely decoupled — swap providers, add providers, or remove the AI layer without touching the UI.

---

## 5. Growth Tracking & Milestones

### What the user experiences

The user snaps before/after photos of their plants. The app tracks leaf count, height, flowering, and overall health over time. When a new leaf unfurls or a plant blooms, the app celebrates with a subtle animation and offers to share a card with friends.

### How it works technically

**Photo journal.** Each plant has a timeline of `JournalEntry` objects (Core Data). An entry can include a photo, a health score (user-rated 1–5), leaf count, height, and freeform notes.

Photos are stored as compressed JPEGs (~500KB per photo) in Core Data using `allowsExternalBinaryDataStorage`, with a thumbnail generated at capture time for the timeline view. The full-resolution photo is loaded on demand when the user taps an entry. Same storage/sync approach as care-event photos (section 3).

**Health scoring.** The health score is user-reported (a simple 1–5 scale), but the app also derives an automatic signal from photo analysis (color vibrancy, leaf droop detection) as a secondary metric. Both are displayed on the health timeline.

**Milestone detection.** The app detects milestones from journal entries:

- **New leaf:** Detected if the user records an increased leaf count and attaches a photo. Vision could theoretically count leaves, but for reliability this is user-reported with a photo attached.
- **Bloom:** User-reported (a toggle on the journal entry).
- **Repotting anniversary:** Calculated from the last recorded repotting event.
- **Growth spurt:** Detected when height or leaf count increases significantly faster than the plant's historical average (simple threshold-based algorithm).

Each milestone triggers an in-app celebration (a SwiftUI animated card overlay) and an optional share sheet for a generated social card.

---

## 6. Environment & Long-Term Insights

### What the user experiences

The app periodically nudges the user with helpful observations: "Your room's humidity dropped this week — consider grouping your plants or using a pebble tray." Seasonal transitions trigger automatic care adjustments: "Days are getting shorter — reduce watering frequency and watch for light deficiency."

### How it works technically

**Climate data.** If the user opts in to background weather data, the app uses `URLSession` to fetch from a free weather API (Open-Meteo, which has no API key requirement) on a daily schedule via `BGTaskScheduler`. The fetched data includes:

- Average temperature (current and 7-day trend)
- Humidity (current and trend)
- Daylight hours (calculated from location and date)

These values are stored in Core Data as a time series (`EnvironmentalReading`), keyed by date and location. Outdoor weather is a weak proxy for indoor conditions, so it informs but does not override the user's reported per-plant placement.

**Seasonal playbook.** The app maintains a season matrix that maps `(latitude_band, month)` → care adjustments. For example:

- Temperate latitude, October → "Reduce watering frequency by 30%"
- Tropical latitude, July → "Maintain humidity above 60%"
- Arid latitude, January → "Watch for cold drafts near windows"

These adjustments are deterministic inputs to the scheduling engine (section 3) — they feed in as adjustment factors alongside placement and adherence, in a defined precedence order (placement overrides climate; climate adjusts the baseline). They're also surfaced in the dashboard as a "Seasonal Tip" card.

**Non-intrusive delivery.** Insights are delivered via:

1. The dashboard's "For You" section (a single card at the top)
2. An optional weekly summary notification (user-configurable)

The goal is to feel like a helpful friend, not an alarm system. Insights that require action (e.g., "watering schedule adjusted for winter") are shown once. Insights that are purely informational (e.g., "humidity is low") include a suggestion but don't repeat.

---

## Cross-Cutting Technical Decisions

### MVVM + @Observable

Every feature follows the same pattern:

```
View ──observes──► ViewModel ──calls──► Service (protocol)
                      │                      │
                      │ owns                  │ injected via
                      ▼                      ▼
                  Model (struct)       Implementation
```

ViewModels are `@Observable` classes. They own the model state and expose it to views, which observe it automatically through the `@Observable` macro's tracking. Services are injected via PointFree's [swift-dependencies](https://github.com/pointfreeco/swift-dependencies) library (`@Dependency` property wrapper), making every ViewModel testable with mock services in a single `withDependencies { ... }` block.

### Core Data + CloudKit

Core Data is the primary persistence layer. CloudKit sync is enabled via the Core Data + CloudKit integration (NSPersistentCloudKitContainer). The conflict resolution policy is "server wins" for simplicity, applied uniformly across all entities.

The `Repository` pattern wraps Core Data operations:

```swift
protocol PlantRepository {
    func fetchAll() async throws -> [Plant]
    func save(_ plant: Plant) async throws
    func delete(_ plant: Plant) async throws
}
```

This makes it trivial to swap Core Data for a REST API later — just write a `RemotePlantRepository` that conforms to the same protocol.

### WidgetKit

Two widget families:
1. **Single plant widget** — shows the next care task for a selected plant
2. **Dashboard widget** — shows all overdue and upcoming tasks across all plants

Widgets read from a shared App Group container that mirrors the Core Data store. The same scheduling function described in section 3 runs in the widget's timeline provider, so the widget can compute due tasks without launching the app.

### Accessibility & Localization

Built in from day one, not retrofitted:

- Every view uses Dynamic Type and supports the largest accessibility sizes.
- All images have accessibility labels. All interactive elements have hints.
- The color scheme uses system colors that adapt to Dark Mode and Increase Contrast.
- Localization supports English and Spanish initially, with `String(localized:)` used throughout. The plant catalog includes localized common names.

### Testing Strategy

- **Unit tests** for the rule engine, scheduling algorithm, season matrix, and care sheet merging (pure logic, no mocks needed).
- **Unit tests with mocks** for ViewModels (mock `PlantRepository`, `AIDiagnosisProvider`, `WeatherService`).
- **Snapshot tests** for key screens (care sheet, dashboard, journal entry) using the SnapshotTesting library.
- **UI tests** for critical flows: onboarding → add plant → log care event → view diagnosis.

The `MockProvider` for the AI service returns canned responses that cover the full decision tree, making the AI layer fully testable without any network calls.

### CI/CD

GitHub Actions runs on every push:

1. Build + test (iOS 26 simulator)
2. Lint (SwiftLint)
3. Upload build artifact to TestFlight (on main branch)

A backend/CI workflow will be added when the Phase 2 backend exists (see Backend section below).

---

## Backend & Data Pipeline (Phase 2)

The iOS app is designed to work fully offline with local storage and on-device AI. The backend extends what's possible:

**REST API.** An API service in the Node ecosystem that mirrors the `Repository` protocols, letting the app sync to a shared database instead of just CloudKit. (Framework choice is a Phase 2 detail.)

**PostgreSQL + Redis.** Plant catalog, user profiles, and care events in PostgreSQL. Redis for caching AI responses and weather data.

**Event tracking.** Client-side analytics events (plant added, care event logged, diagnosis viewed) are queued locally and sent in batches. The event schema is designed before the first line of backend code is written, ensuring forward compatibility.

**dbt pipeline.** Plant health score calculations, user retention vs. plant survival cohorts, and seasonal trend analysis run as dbt models on the analytics schema. For now, the app's on-device recommendations stay static-ish (the curated rule tree and bundled catalog). The long-term path is for backend analytics to ship catalog updates or rule-tree refinements back to the app — but that feedback mechanism is underspecified by design and will be shaped when Phase 2 is real.

The app degrades gracefully when the backend is unavailable — it's the same code path as when the user is offline. CloudKit provides baseline sync, and the backend provides the analytics and AI enrichment layer.

---

## Why This Works as a Portfolio

- **Every feature has a clear user benefit** — no tech for tech's sake.
- **The architecture is visible in the code** — protocol-based services, MVVM with `@Observable`, repository pattern, DI container.
- **The AI layer is honest** — on-device intelligence that always works, optional AI enrichment that demonstrates API integration skills.
- **Testing is designed in, not bolted on** — mock providers, pure logic functions, snapshot tests.
- **Offline-first is a feature, not an excuse** — the app is fully functional on a plane, and better with a network.
- **The backend pipeline tells a story** — even though it's phase 2, the event schema and repository pattern show you've thought about the full system.
