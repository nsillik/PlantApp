# Phase 4 — Code Health & Pattern Consolidation

**Goal:** Eliminate duplication, standardize patterns, harden correctness, and reduce boilerplate across the entire codebase. No new user-facing features.

**Depends on:** Phases 0–3.

**Back in:** [PLAN.md](PLAN.md)

---

## Steps

### 4.1 `CareEventType` Extension

Add computed properties so the 6 places that switch on `CareEventType` collapse to one source of truth.

#### 4.1.1 Add extension to `Domain.swift`

```swift
extension CareEventType {
    var localizedLabel: String { … }
    var systemImage: String { … }
    var tint: Color { … }
    var scheduleKeyPath: WritableKeyPath<CareSchedule, Date?> { … }
}
```

Import `SwiftUI` where `Color` is needed (or use a separate `import struct SwiftUI.Color`).

#### 4.1.2 Adopt across all call sites

Replace hand-written switches in:

| File | Lines | Replace with |
|---|---|---|
| `CareEventConfirmationView.swift:96–121` | `icon(for:)`, `color(for:)`, `label(for:)` | `eventType.systemImage`, `.tint`, `.localizedLabel` |
| `CareEventHistoryView.swift:42–67` | same three functions | same |
| `HomeView.swift:459–466` | `taskLabel(for:)` in `TaskRow` | `eventType.localizedLabel` |
| `PlantDetailView.swift:244–255` | `CareActionButton` call site hard-coded color/icon | `eventType.systemImage`, `.tint` |
| `HomeViewModel.swift:89–114` | 4-case `lastX` assignment | `scheduleKeyPath` (see 4.2) |
| `PlantDetailViewModel.swift:143–152` | 4-case assignment | `scheduleKeyPath` |

**Acceptance:** Every view and VM that references a CareEventType icon/color/label uses the extension properties. Zero hard-coded SF Symbol or color strings per event type remain outside `Domain.swift`.

---

### 4.2 `CareSchedule.recordingEvent(_:on:)` + Adherence Math

#### 4.2.1 Add method on `CareSchedule` in `Domain.swift`

```swift
extension CareSchedule {
    mutating func recordEvent(_ type: CareEventType, on date: Date) {
        let keyPath = type.scheduleKeyPath
        if let last = self[keyPath: keyPath] {
            let daysLate = Calendar.current.dateComponents([.day], from: last, to: date).day ?? 0
            adherenceOffset = max(0, adherenceOffset + daysLate / 3 - 1)
        }
        self[keyPath: keyPath] = date
    }
}
```

#### 4.2.2 Replace duplicated logic

- `HomeViewModel.logCareEvent` (`HomeView.swift:89–114`): the 4-branch `if let last … updated.lastX = Date()` → `updated.recordEvent(eventType, on: Date())`
- `PlantDetailViewModel.confirmCareEvent` (`PlantDetailView.swift:143–152`): same → `updated.recordEvent(eventType, on: Date())`

**Acceptance:** `CareSchedule` owns the adherence-offset adjustment. Both ViewModels call `schedule.recordEvent(_:on:)` with zero per-event-type branching.

---

### 4.3 Single-Transaction Event+Schedule Write

#### 4.3.1 Add atomic `recordCareEvent` to `CareScheduleRepository`

New method on the protocol:

```swift
protocol CareScheduleRepository: Sendable {
    // existing …
    /// Persists a care event and atomically updates the schedule.
    func recordCareEvent(_ event: CareEvent, updatingScheduleFor plantID: UUID) async throws
}
```

#### 4.3.2 Implement on `CoreDataCareScheduleRepository`

Perform the event insert + schedule fetch/update in a single `withBackgroundContext` call.

#### 4.3.3 Adopt in ViewModels

- `HomeViewModel.logCareEvent` → call `scheduleRepository.recordCareEvent(event, updatingScheduleFor: plantID)`
- `PlantDetailViewModel.confirmCareEvent` → same

#### 4.3.4 Remove `CareEventRepository` from ViewModel dependencies

After this, `HomeViewModel` and `PlantDetailViewModel` no longer need a separate `@Dependency(\.careEventRepository)` — the schedule repository handles both via `recordCareEvent`. Remove the `careEventRepository` injected property from both ViewModels and their tests.

**Acceptance:** Event + schedule persist atomically. If the schedule write fails, the event is never persisted. ViewModels hold one fewer dependency.

---

### 4.4 `@DependencyClient` Macro for Unimplemented Stubs

Replace all hand-rolled `Unimplemented*` structs in `DependencyRegistration.swift` with `@DependencyClient`.

#### 4.4.1 Convert protocols

Apply `@DependencyClient` to the protocol declarations (or their extensions) in `PlantRepository.swift`:

```swift
@DependencyClient
struct PlantRepositoryClient: PlantRepository { … }
```

Each dependency key in `DependencyRegistration.swift` removes its `Unimplemented*` struct and instead sets:

```swift
private enum PlantRepositoryKey: DependencyKey {
    static let liveValue: PlantRepository = CoreDataPlantRepository(
        persistenceService: PersistenceController.shared
    )
    static let testValue: PlantRepository = PlantRepositoryClient()
}
```

Affected protocols:
- `PlantRepository`
- `UserProfileRepository`
- `CareScheduleRepository`
- `CareEventRepository` (until/unless removed in 4.3)
- `NotificationScheduling`
- `PlantIdentificationService`
- `CatalogService`
- `CitySearchService`
- `ClimateService`

#### 4.4.2 Remove the hand-written Unimplemented structs

Delete `UnimplementedPlantRepository`, `UnimplementedUserProfileRepository`, `UnimplementedCareScheduleRepository`, `UnimplementedCareEventRepository`, `UnimplementedCatalogService`, `UnimplementedCitySearchService`, `UnimplementedClimateService`, `UnimplementedNotificationScheduler` from `DependencyRegistration.swift`.

**Acceptance:** Zero hand-written `Unimplemented*` structs in `DependencyRegistration.swift`. Each dependency key is ≤10 lines. All `testValue` entries compile and `reportIssue` as before.

---

### 4.5 `PersistenceService` Fetch/Upsert Helpers

#### 4.5.1 Add helpers to `PersistenceService`

```swift
extension PersistenceService {
    func fetchAll<T: NSManagedObject>(
        _ request: NSFetchRequest<T>,
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor]? = nil
    ) async throws -> [T]

    func fetchFirst<T: NSManagedObject>(
        _ request: NSFetchRequest<T>,
        predicate: NSPredicate?
    ) async throws -> T?

    func upsert<T: NSManagedObject>(
        _ request: NSFetchRequest<T>,
        predicate: NSPredicate?,
        configure: (T) -> Void
    ) async throws

    func deleteAll<T: NSManagedObject>(
        _ request: NSFetchRequest<T>,
        predicate: NSPredicate?
    ) async throws
}
```

Implementation via repeated `withBackgroundContext` pattern.

#### 4.5.2 Compact `CoreData*Repository` implementations

Rewrite `CoreDataPlantRepository`, `CoreDataUserProfileRepository`, `CoreDataCareScheduleRepository`, `CoreDataCareEventRepository` to use the helpers. Each method collapses to a one-liner.

**Acceptance:** No actor method in a repository exceeds 3 lines, except `recordCareEvent` (4.3) which needs the single-transaction sequence.

---

### 4.6 Remove `careSheet` Parameter from `SchedulingEngine`

#### 4.6.1 Drop the parameter

Remove `careSheet: CareSheet` from `SchedulingEngine.nextDueDates` signature. The parameter is documented as "reserved for future use; not yet factored into due dates" and every call site passes an empty stub.

#### 4.6.2 Update call sites

- `HomeViewModel.recomputeTasks` (`HomeView.swift:150`, line `:186`)
- `HomeViewModel.reRegisterNotifications` (`HomeView.swift:150`)

Remove the `CareSheet(water: "", light: "", soil: "", humidity: "", toxicity: "", commonProblems: "")` literal.

**Acceptance:** `SchedulingEngine` signature is `(schedule:, species:, season:, plantName:, now:)`. No dead fake-CareSheet construction anywhere.

---

### 4.7 Stable `CareTask.id` + Persisted Completion

#### 4.7.1 Deterministic task ID

Replace `CareTask(id: UUID(), …)` in `SchedulingEngine.nextDueDates` with a stable ID derived from `plantID + eventType`:

```swift
// In CareTask or SchedulingEngine
static func taskID(plantID: UUID, eventType: CareEventType) -> UUID { … }
```

#### 4.7.2 Persist completed status

Instead of threading `completedTasks: Set<CareTaskKey>` through `loadAll → recomputeTasks`, check completion by asking the repository: "does this plant have an event of this type logged today or after today's due date?".

Option A (simpler / recommended for Phase 4): Add `CareTaskCompleted` — a `(plantID, eventType, date)` triple persisted in CoreData. The repository gets a `fetchCompletedTasks(since: Date) -> Set<CareTaskKey>` method. `HomeViewModel.recomputeTasks` queries it once at the top and marks matching tasks.

#### 4.7.3 Remove `CareTaskKey` / `completedTasks` plumbing

Delete `CareTaskKey` from `HomeView.swift:204–207`. Remove `completedTasks` parameter from `loadAll` and `recomputeTasks`. Remove the `completedKey` logic from `logCareEvent`.

**Acceptance:** `CareTask.id` is stable across reloads. Completed tasks stay marked complete on subsequent `loadAll()` calls without a transient parameter. `CareTaskKey` no longer exists.

---

### 4.8 Remove Dead Domain Models & Entities

#### 4.8.1 Delete `JournalEntry` and `EnvironmentalReading`

From `Domain.swift:270–330`: remove both structs.

#### 4.8.2 Delete Core Data entities

From `PlantEntity.swift:79–106`: remove `JournalEntryEntity` and `EnvironmentalReadingEntity` classes.

From `Verdigris.xcdatamodeld`: remove both `<entity name="JournalEntryEntity" …>` and `<entity name="EnvironmentalReadingEntity" …>` entries.

#### 4.8.3 Delete `StubServices.swift`

Remove `app/Sources/Verdigris/Services/StubServices.swift` entirely. The `Void`-typed `weatherService` and `aiDiagnosisProvider` dependency keys exist only to compile future code — YAGNI.

**Acceptance:** No references to `JournalEntry`, `EnvironmentalReading`, their entities, `weatherService`, or `aiDiagnosisProvider` remain anywhere in the app target.

---

### 4.9 `CitySearchSession` Extraction

Extract shared search state so `SettingsViewModel` and `LocationOnboardingViewModel` reuse the same logic.

#### 4.9.1 Create `CitySearchSession`

```swift
@MainActor
@Observable
final class CitySearchSession {
    var searchText = ""
    var isSearching = false
    var isResolving = false
    var errorMessage: String?
    var suggestions: [CitySuggestion] = []
    var selectedCity: City?

    @ObservationIgnored
    @Dependency(\.citySearchService) private var searchService
    @ObservationIgnored
    @Dependency(\.climateService) private var climateService

    func searchCities() { … }           // debounced search
    func selectSuggestion(_: CitySuggestion) { … }   // resolve + fill
    func climateLabel(for: City) -> String { … }
    func reset() { … }
}
```

On `selectSuggestion` failure, restore saved suggestions (adopt the `LocationOnboardingViewModel` behavior — it's correct; `SettingsViewModel` discarding them is a bug).

#### 4.9.2 Adopt in `LocationOnboardingViewModel`

Replace the `searchText`/`isLoading`/`isResolving`/`errorMessage`/`suggestions`/`selectedCity` properties, `searchCities()`, `selectSuggestion(_:)`, and `climateLabel(for:)` with a single `CitySearchSession`:

```swift
@MainActor
@Observable
final class LocationOnboardingViewModel {
    let citySession = CitySearchSession()
    // only onboarding-specific state + buildProfile/cancel remain
    func buildProfile() -> UserProfile? { … }
}
```

#### 4.9.3 Adopt in `SettingsViewModel`

Same replacement. The `confirmCity()` method persists via `citySession.selectedCity` and writes to `UserProfileRepository`. The `loadProfile()` method populates `searchText` from the existing profile.

#### 4.9.4 Update views

`LocationOnboardingView` and `SettingsView` read `viewModel.citySession.suggestions`, `viewModel.citySession.isSearching`, etc. The views' `body` structure is simplified (see 4.13–4.14).

**Acceptance:** `CitySearchSession` owns all search/resolve state and debounce logic. Both ViewModels compose a `CitySearchSession` with zero duplicated code. Behavior on resolution failure is consistent (both restore suggestions).

---

### 4.10 Fix `CitySearchError.resolutionFailed` Throwing

In `MapKitCitySearchService.resolve` (`CitySearchService.swift:73`), change `throw CitySearchError.notFound` to `throw CitySearchError.resolutionFailed` when `response?.mapItems.first` is `nil`. The `.notFound` case is for search returning zero results; the `.resolutionFailed` case is for when a resolved coordinate lookup fails.

**Acceptance:** `.resolutionFailed` is thrown in the correct code path. The `UnimplementedCitySearchService.resolve` already throws `.resolutionFailed` — no change needed there.

---

### 4.11 Fix `PersistenceController.inMemory()` Store Type

In `PersistenceController.init(inMemory:)` (`PersistenceController.swift:46–47`), replace:

```swift
container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
```

with:

```swift
guard let description = container.persistentStoreDescriptions.first else {
    fatalError("No persistent store description found")
}
description.url = URL(fileURLWithPath: "/dev/null")
description.type = NSInMemoryStoreType
```

Also set `container.viewContext.automaticallyMergesChangesFromParent = true` in the `inMemory` init (currently only set in the `shared` init).

**Acceptance:** In-memory store uses `NSInMemoryStoreType`. `automaticallyMergesChangesFromParent` is set consistently for both shared and in-memory.

---

### 4.12 Remove Dead `\.managedObjectContext` Injection

In `VerdigrisApp.swift:13, 16`: remove `.environment(\.managedObjectContext, persistenceService.viewContext)` from both `HomeView` and `OnboardingRootView`. Nothing reads the main context via `@FetchRequest` or `@Environment(\.managedObjectContext)`.

Remove `viewContext` from `PersistenceService` protocol and `PersistenceController` if nothing else reads it.

**Acceptance:** No `.environment(\.managedObjectContext, …)` injection anywhere in the app. `PersistenceService` protocol no longer exposes `viewContext`.

---

### 4.13 View Decomposition — `PlantDetailView`

Split `PlantDetailView.body` (`PlantDetailView.swift:214–324`) into component vars:

| Var | Content |
|---|---|
| `private var headerSection` | `TextField` + `PlantSpecies` name/scientific |
| `private var careActionsSection` | `LazyVGrid` of `CareActionButton` |
| `private var placementSection` | Light + Humidity pickers |
| `private var careGuideSection` | `CareSheetView` or loading |
| `private var historySection` | `CareEventHistoryView` |

`body` becomes:

```swift
ScrollView {
    VStack(alignment: .leading, spacing: 16) {
        headerSection
        Divider()
        careActionsSection
        Divider()
        placementSection
        Divider()
        careGuideSection
        if !viewModel.careEvents.isEmpty {
            Divider()
            historySection
        }
    }
    .padding()
}
```

**Acceptance:** `body` ≤ 20 lines. Each section var is independently scoped and self-documenting.

---

### 4.14 View Decomposition — `SettingsView`

Split the `Form` content (`SettingsView.swift:144–234`) into:

| Var | Content |
|---|---|
| `private var locationSection` | Current location display + edit button |
| `private var editingLocationSection` | Search field, progress, error, suggestions list, confirmed city card, confirm button |
| `private var onboardingSection` | "Reset Onboarding" button |
| `private var aiProviderSection` | Future placeholder text |

`body` becomes:

```swift
NavigationStack {
    Form {
        Section(String(localized: "Location")) {
            if viewModel.isEditingLocation {
                editingLocationSection
            } else {
                locationSection
            }
        }
        Section(String(localized: "Onboarding")) {
            onboardingSection
        }
        Section(String(localized: "AI Provider")) {
            aiProviderSection
        }
    }
    .navigationTitle(String(localized: "Settings"))
}
```

**Acceptance:** `body` ≤ 25 lines. Each section is a separate var.

---

### 4.15 View Decomposition — `LocationOnboardingView`

Split the `VStack` content (`LocationOnboardingView.swift:122–206`) into:

| Var | Content |
|---|---|
| `private var searchField` | `HStack` with magnifying glass + `TextField` |
| `private var loadingIndicator` | `ProgressView` (both search + resolve states) |
| `private var errorMessageView` | Optional error text |
| `private var suggestionsList` | `List` of `CitySuggestion` buttons |
| `private var confirmedCityCard` | City name + climate label + confirm button |

**Acceptance:** `body` ≤ 30 lines.

---

### 4.16 HomeView Cleanup

#### 4.16.1 Move notification-request logic to `HomeViewModel`

Extract the `onAppear` inline `@Dependency` read + permission check (`HomeView.swift:365–373`) into:

```swift
// In HomeViewModel
func checkNotificationPermissionIfNeeded() async -> Bool {
    // returns true if alert should be shown
}
```

The View sets `showNotificationAlert = await viewModel.checkNotificationPermissionIfNeeded()`.

#### 4.16.2 Remove redundant `loadAll()` calls

- Remove the `onAppear` Task that re-runs `loadAll()` (`HomeView.swift:361–364`) — `.task` already does it.
- Remove the `.onChange(of: viewModel.showCatalog)` that calls `loadAll()` (`HomeView.swift:296–298`). Instead, the `CatalogBrowseView` and `plantCameraAddFlow` callbacks already trigger a reload — keep only those, but ensure exactly one reload path per add event.
- After the `CatalogBrowseView` callback (`HomeView.swift:267`) and the `plantCameraAddFlow` callback (`HomeView.swift:282`), both do `Task { await viewModel.loadAll() }`. These are the correct (and only) reload triggers after a plant is added.

#### 4.16.3 Move presentation flags to View

Remove `viewModel.showCatalog` from `HomeViewModel`. Add `@State private var showCatalog = false` to `HomeView`. Wire the catalog sheet to `$showCatalog`.

**Acceptance:** No `@Dependency` read in View code. No redundant `loadAll()` calls. All transient presentation state lives in `@State` on the View.

---

### 4.17 ViewModel Init Pattern Standardization

Standardize every ViewModel construction to `init(viewModel: X = X())`:

| ViewModel | Current | Fix |
|---|---|---|
| `HomeViewModel` | `init(viewModel: HomeViewModel = HomeViewModel())` ✅ | Already done |
| `PlantDetailViewModel` | `init(plant: Plant)` → `State(initialValue:)` | Change to `init(viewModel: PlantDetailViewModel)` defaulting to `PlantDetailViewModel(plant:)` |
| `SettingsViewModel` | `@State private var viewModel = SettingsViewModel()` | Add `init(viewModel: SettingsViewModel = SettingsViewModel())` for testability |
| `CatalogBrowseViewModel` | `@State private var viewModel = CatalogBrowseViewModel()` | Same |
| `LocationOnboardingViewModel` | `@State private var viewModel = LocationOnboardingViewModel()` | Same |
| `AddPlantViewModel` | `init(species:)` → `State(initialValue:)` | Change to `init(viewModel: AddPlantViewModel)` defaulting to `AddPlantViewModel(species:)` |
| `CameraViewModel` | `@State private var viewModel = CameraViewModel()` | Add `init(viewModel: CameraViewModel = CameraViewModel())` |

**Acceptance:** Every View has an optional `viewModel:` init parameter. Tests and previews can swap VMs without changing View code. Consistent pattern: `@State private var viewModel: VM` + `init(viewModel: VM = VM(…))`.

---

### 4.18 Standardize `Placement` Picker Construction

Replace the hand-enumerated `Picker` cases in `AddPlantView.swift:73–88` with `ForEach(LightPlacement.allCases, id: \.self)` / `ForEach(HumidityPlacement.allCases, id: \.self)` — matching `PlantDetailView.swift:271–287`.

**Acceptance:** Both `AddPlantView` and `PlantDetailView` use `ForEach(…allCases)` for placement pickers.

---

### 4.19 Standardize Camera Entry Flow

Replace `AddPlantView`'s inline `.fullScreenCover { PlantCameraView(…) }` (`AddPlantView.swift:119–128`) with the `.plantCameraAddFlow(isPresented:onSaved:)` modifier. The `PlantCameraFlow` modifier already handles the dismiss-then-sheet sequencing that `AddPlantView` manually reproduces.

**Acceptance:** The `plantCameraAddFlow` view modifier (`PlantCameraFlow.swift`) is the single entry point for the camera-add-plant flow site-wide. `AddPlantView` no longer constructs a `PlantCameraView` directly.

---

### 4.20 Standardize Error Reporting

Every ViewModel that surfaces user-facing errors exposes `var errorMessage: String?`. Every ViewModel that encounters developer-level errors calls `reportIssue(_:)`. Enforce the boundary:

| Kind | Channel | Example |
|---|---|---|
| User should see & act on it | `errorMessage: String?` on VM | Catalog failed to load, plant save failed |
| Developer should fix it | `reportIssue(_:)` | Unimplemented service endpoint, corrupted entity on disk |

**Current state to fix:**
- `PlantDetailViewModel` (`PlantDetailView.swift:54–58, 67–71, 82–87, 96–101, 156`) swallows user-visible errors via `reportIssue` → surface as `errorMessage` instead.
- `PersistenceController` (`PersistenceController.swift:29, 52, 63`) uses `print(…)` → replace with `reportIssue`.

**Acceptance:** Every VM has an `errorMessage` property for user-facing errors. `print()` is never used for error logging — only `reportIssue`.

---

### 4.21 `PlantDetailViewModel` Save-First Mutations

#### 4.21.1 `confirmCareEvent`

Before: mutate `careEvents` eagerly, then save event + schedule (`PlantDetailView.swift:130–147`). If save fails, UI is optimistic but data is wrong.

After: save event + schedule first, then insert into `careEvents` on success.

#### 4.21.2 `updatePlacement` / `updateName`

Before: mutate `plant` in memory, fire-and-forget save in `Task {}` (`PlantDetailView.swift:64–73, 79–88, 93–102`).

After: save first via the repository, then mutate `plant` on success. Use a single `do/catch` that sets `errorMessage` on failure and reverts the in-memory mutation.

**Acceptance:** No optimistic in-memory mutation that can diverge from persisted state. Errors surface as `errorMessage`.

---

### 4.22 Fix `OnboardingCoordinator.hasCompletedOnboarding` Observability

Change `hasCompletedOnboarding` from a computed `Bool` reading `UserDefaults` (`OnboardingCoordinator.swift:21–23`) to a stored `@Observable` property:

```swift
var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: onboardingKey)
```

Update `completeOnboarding()` and `resetOnboarding()` to set the property AND persist to `UserDefaults`.

**Acceptance:** `hasCompletedOnboarding` triggers `@Observable` re-renders. `VerdigrisApp.onChange(of: coordinator.hasCompletedOnboarding)` fires correctly.

---

### 4.23 Fix `CameraViewModel.detectPlant` Concurrency

Remove `nonisolated` from `CameraViewModel.detectPlant(in:)` (`CameraViewModel.swift:55`). The only call site is inside `Task { @MainActor in … }` in `CameraViewController.captureOutput` (`CameraPreviewView.swift:202`), which already hops to MainActor. The `nonisolated` attribute is both unnecessary and a potential MainActor isolation violation since the method accesses `self.identificationService`.

**Acceptance:** `detectPlant(in:)` is `@MainActor`-isolated by default (class is `@MainActor`). No compiler warning about Sendability.

---

### 4.24 Make `DetectedBoundingBox` Identifiable

Add `Identifiable` conformance to `DetectedBoundingBox` in `Domain.swift` since `CGRect` already adopts `Sendable` and the struct is `Equatable`. Use a stable ID:

```swift
struct DetectedBoundingBox: Identifiable, Sendable, Equatable {
    var id: String { "\(normalizedRect.origin.x),\(normalizedRect.origin.y),\(normalizedRect.width),\(normalizedRect.height)" }
    let normalizedRect: CGRect
    let confidence: Double
}
```

Then replace `ForEach(Array(viewModel.detectionResult.boundingBoxes.enumerated()), id: \.offset)` in `PlantCameraView.swift:78` with `ForEach(viewModel.detectionResult.boundingBoxes)`.

**Acceptance:** `DetectedBoundingBox` is `Identifiable`. Detection overlay uses `.id` instead of `\.offset`.

---

### 4.25 Replace `print()` with `reportIssue` in `PersistenceController`

Replace the three `print(…)` calls in `PersistenceController.swift:29, 52, 63` with `reportIssue(…)`. Add `import IssueReporting` at the top.

**Acceptance:** Zero `print()` calls in production code.

---

### 4.26 Note `@preconcurrency` Intents

Add a comment block at the top of each file using `@preconcurrency import` explaining why it's still needed:

- `CoreData` — `NSManagedObjectContext` is not `@Sendable` in the SDK version pinned, despite Apple's annotation progress.
- `MapKit` — `MKLocalSearchCompleter` and its delegate are not fully Sendable-annotated.
- `AVFoundation` — `AVCaptureSession` / `AVCaptureVideoDataOutputSampleBufferDelegate` are not fully Sendable-annotated.

**Acceptance:** Every `@preconcurrency import` is accompanied by a comment explaining why.

---

### 4.27 Fix Climate Label Localization

Replace interpolated `String(localized: "\(profile.climateClassification.localizedLabel) climate")` in:

- `SettingsView.swift:151`
- `LocationOnboardingView.swift:184`

with a single-key lookup per climate classification:

```swift
// In ClimateClassification
var localizedClimateLabel: String {
    String(localized: "climate.label.\(rawValue)")
}
```

Register `climate.label.temperate`, `climate.label.tropical`, `climate.label.arid` as full-phrase entries in the String Catalog (e.g., "Temperate climate", "Clima templado").

**Acceptance:** No dynamic interpolation inside `String(localized:)` that involves another already-localized substring. Climate labels localize atomically.

---

### 4.28 Extract `ThumbnailRow` Shared Component

Create `ThumbnailRow` (replacing the identical `PlantRowView` in `HomeView.swift:469` and `SpeciesRowView` in `CatalogBrowseView.swift:106`):

```swift
struct ThumbnailRow: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let imageColor: Color

    var body: some View { … }
}
```

Use `ThumbnailRow` in `PlantRowView` (now a thin wrapper that passes `plant.name` + `plant.placementLight?.label`) and directly in `CatalogBrowseView.SpeciesRowView`.

**Acceptance:** `PlantRowView` and `SpeciesRowView` are thin wrappers over `ThumbnailRow`. No duplicate `ZStack { RoundedRectangle … Image(systemName: "leaf") … }` layout.

---

### 4.29 Test Cleanup

#### 4.29.1 Consolidate `MockNoopNotificationScheduler` into `Mocks.swift`

Move the private `MockNoopNotificationScheduler` from `Phase2ViewModelTests.swift:163–168` to `app/Tests/VerdigrisTests/Mocks.swift`. Add it to the `// MARK: - No-op mocks` section.

#### 4.29.2 Drop redundant `await MainActor.run` in `Phase2ViewModelTests`

The suite is `@MainActor`, so `await MainActor.run { HomeViewModel() }` is redundant. Replace with `HomeViewModel()` directly.

#### 4.29.3 Remove `MockInMemoryPlantRepository.addPlant` non-protocol method

Replace `await plantRepo.addPlant(testPlant)` in tests with `try await plantRepo.save(testPlant)` (which is on the `PlantRepository` protocol and does the same thing — upserts).

Delete the `addPlant` method from `MockInMemoryPlantRepository`.

#### 4.29.4 Consolidate test mocks

The `MockCatalogService` and `FailingCatalogService` and `MockAddPlantRepository` in `ViewModelTests.swift:128–160` overlap with `MockInMemoryCatalogService` and `MockInMemoryPlantRepository` in `Mocks.swift`. Consolidate into `Mocks.swift` and remove from `ViewModelTests.swift`.

**Acceptance:** All curated mock types live in `Mocks.swift`. No test file defines a private mock that another test file duplicates.

---

## Phase 4 Exit Criteria

- [ ] `CareEventType` has `localizedLabel`, `systemImage`, `tint`, and `scheduleKeyPath` extensions; all 6 call sites use them
- [ ] `CareSchedule` has `recordEvent(_:on:)`; both VMs call it; zero per-event-type branching in VMs
- [ ] `CareScheduleRepository.recordCareEvent(…)` persists event + schedule atomically; both VMs use it
- [ ] All `Unimplemented*` structs deleted; `@DependencyClient` generates test values
- [ ] `PersistenceService` has `fetchAll`, `fetchFirst`, `upsert`, `deleteAll` helpers; all repository implementations collapsed to one-liners
- [ ] `SchedulingEngine.nextDueDates` signature has no `careSheet` parameter; no empty `CareSheet` stubs constructed
- [ ] `CareTask.id` is stable based on `plantID + eventType`; completed status persists across reloads
- [ ] `CareTaskKey` deleted; `completedTasks` parameter plumbing removed from `loadAll`/`recomputeTasks`
- [x] `JournalEntry` and `EnvironmentalReading` domain models + Core Data entities deleted from app and schema
- [x] `StubServices.swift` deleted; zero `Void`-typed dependency keys
- [ ] `CitySearchSession` extracted; `SettingsViewModel` and `LocationOnboardingViewModel` compose it with zero search/resolve duplication
- [ ] `CitySearchError.resolutionFailed` thrown in `MapKitCitySearchService.resolve` (not `.notFound`)
- [ ] `PersistenceController.inMemory()` uses `NSInMemoryStoreType`; `automaticallyMergesChangesFromParent` true for both shared and in-memory
- [ ] No `\.managedObjectContext` environment injection; `viewContext` removed from `PersistenceService` protocol
- [ ] `PlantDetailView.body` ≤ 20 lines split into sections
- [ ] `SettingsView.body` ≤ 25 lines split into sections
- [ ] `LocationOnboardingView.body` ≤ 30 lines split into sections
- [ ] No `@Dependency` read in `HomeView`; notification-request logic moved to `HomeViewModel`
- [ ] Zero redundant `loadAll()` invocations in `HomeView`
- [ ] All transient presentation flags in `@State` on Views, not on ViewModels
- [ ] Every View has `init(viewModel: VM = VM(…))`; no bare `@State private var viewModel = VM()`
- [ ] All `Picker` for `LightPlacement`/`HumidityPlacement` use `ForEach(…allCases)`
- [ ] `AddPlantView` uses `.plantCameraAddFlow` modifier; no inline `.fullScreenCover { PlantCameraView }`
- [ ] Every VM has `errorMessage: String?` for user-facing errors; `reportIssue` for dev errors; zero `print()`
- [ ] `PlantDetailViewModel` saves first, mutates second (no optimistic divergence)
- [ ] `OnboardingCoordinator.hasCompletedOnboarding` is a stored `@Observable` var; `VerdigrisApp.onChange` fires correctly
- [ ] `CameraViewModel.detectPlant` is `@MainActor` (no `nonisolated`)
- [ ] `DetectedBoundingBox` is `Identifiable`; `PlantCameraView` detection overlay uses `ForEach(…boundingBoxes)`
- [ ] Zero `print()` calls; every log uses `reportIssue`
- [ ] Every `@preconcurrency import` has an explanatory comment
- [ ] Climate labels localize atomically via `climate.label.\(rawValue)` keys; no substring interpolation
- [ ] `ThumbnailRow` extracted; `PlantRowView` and `SpeciesRowView` are thin wrappers
- [ ] `MockNoopNotificationScheduler` lives once in `Mocks.swift`
- [ ] `Phase2ViewModelTests` uses no `await MainActor.run { }` redundantly
- [ ] `MockInMemoryPlantRepository` has no `addPlant` method; tests use `save(_:)`
- [ ] All test mocks live in `Mocks.swift`; zero private mock duplicates across test files
- [ ] All existing unit tests pass
- [ ] All existing snapshot tests pass (may need regeneration for UI changes in View decomposition)
- [ ] SwiftLint passes with zero warnings/errors
- [ ] App builds via `tuist build`
- [ ] Tests pass via `tuist test --device "iPhone 17 Pro"`
