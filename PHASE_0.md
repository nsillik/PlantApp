# Phase 0 — Foundation

**Goal:** A building, tested, CI-green shell with all architectural plumbing in place. Kick off both long-lead workstreams.

**Depends on:** Nothing.

**Back in:** [PLAN.md](PLAN.md)

---

## Steps

### 0.1 Set up Tuist + mise project
- [x] Create `.mise.toml` at the project root to pin tool versions (use latest available):
  ```toml
  [tools]
  tuist = "4.200.5"
  swiftlint = "0.63.3"
  ```
- [x] Run `mise install` to download pinned tools
- [x] Create `Tuist.swift` at the project root:
  ```swift
  import ProjectDescription

  let tuist = Tuist(
      fullHandle: "verdigris/verdigris",
      project: .tuist(
          generationOptions: .options(
              enforceExplicitDependencies: true
          )
      )
  )
  ```
- [x] Create `Workspace.swift` at the project root (references the app project):
  ```swift
  import ProjectDescription

  let workspace = Workspace(
      name: "Verdigris",
      projects: [
          "app",
      ]
  )
  ```
- [x] Create `app/Project.swift` with the app target and test target (development team `T9G4KUKSVP`):
  ```swift
  import ProjectDescription

  let project = Project(
      name: "Verdigris",
      options: .options(
          automaticSchemesOptions: .enabled
      ),
      settings: .settings(
          base: [
              "SWIFT_VERSION": "6.0",
              "IPHONEOS_DEPLOYMENT_TARGET": "26.0",
              "DEVELOPMENT_TEAM": "T9G4KUKSVP",
          ]
      ),
      targets: [
          Target(
              name: "Verdigris",
              platform: .iOS,
              product: .app,
              bundleId: "com.verdigris",
              infoPlist: .extendingDefault(with: [
                  "NSCameraUsageDescription": "Verdigris uses the camera to identify plants and diagnose problems.",
                  "UILaunchScreen": [:],
              ]),
              sources: ["Sources/**"],
              resources: ["Resources/**"],
              dependencies: []
          ),
          Target(
              name: "VerdigrisTests",
              platform: .iOS,
              product: .unitTests,
              bundleId: "com.verdigris.tests",
              infoPlist: .default,
              sources: ["Tests/**"],
              dependencies: [
                  .target(name: "Verdigris"),
              ]
          ),
      ]
  )
  ```
- [x] Create the monorepo directory structure:
  ```
  .mise.toml                   # tool versions
  Tuist.swift                  # workspace config
  Tuist/Package.swift          # SPM dependencies (Tuist-managed)
  Workspace.swift              # workspace referencing "app"
  app/                         # iOS app (MVP Phases 0–3)
    Project.swift
    Sources/Verdigris/
    Sources/Verdigris/Features/
    Sources/Verdigris/Services/
    Sources/Verdigris/Models/
    Sources/Verdigris/Core/
    Resources/
    Tests/VerdigrisTests/
  backend/                     # Phase 2 placeholder
    .gitkeep
  data-pipeline/               # Phase 2 placeholder
    .gitkeep
  ```
- [x] Add `.gitignore` (tuist generates `.xcodeproj` and `.xcworkspace`; they should be ignored):
  ```
  *.xcodeproj
  *.xcworkspace
  Derived/
  ```
- [x] Run `tuist generate` from the project root and verify the workspace opens in Xcode
- [x] Configure signing in the generated project (development team `T9G4KUKSVP` is already in `Project.swift`)
- [x] Add entitlements: App Group (`group.com.verdigris.shared`), CloudKit (container identifier `com.verdigris.cloudkit`)
- [x] Run `tuist build` to verify the project compiles on iOS 26 simulator

**Acceptance:**
- `mise install` succeeds and makes tuist + swiftlint available
- `tuist generate` produces a workspace with the app project included
- The generated workspace opens in Xcode and builds to an iOS 26 simulator
- Bundled `.xcodeproj`/`.xcworkspace` are gitignored (source of truth is `Project.swift` + `Workspace.swift`)
- Monorepo directory structure matches the layout above (with placeholder dirs)

### 0.2 Add SPM dependencies via tuist
- [x] Create `app/Package.swift` to declare external dependencies:
  ```swift
  // swift-tools-version: 6.0
  import PackageDescription

  let package = Package(
      name: "VerdigrisDependencies",
      dependencies: [
          .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.8.0"),
          .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.18.0"),
      ]
  )
  ```
- [x] Reference external dependencies in `app/Project.swift` by adding `.external(name:)` to each target's `dependencies` array
- [x] Run `tuist install` from the project root to resolve and download SPM packages
- [x] Run `tuist generate` and verify packages are linked in the generated project

**Acceptance:**
- `tuist install` succeeds (resolves all packages)
- `tuist build` succeeds
- `import Dependencies` and `import SnapshotTesting` compile in source files

### 0.3 Set up SwiftLint (via mise)
- [x] SwiftLint version is already pinned in `.mise.toml` (from step 0.1)
- [x] Add `.swiftlint.yml` with baseline rules (opt-in to rules that match Swift/SwiftUI conventions)
- [x] Resolve any initial lint errors

**Acceptance:**
- `swiftlint lint` exits cleanly (no errors; warnings acceptable initially)

### 0.4 Core Data model + NSPersistentCloudKitContainer
- [x] Define initial entity schema in the Core Data model:
  - `UserProfile` (city, latitude, longitude, climateClassification)
  - `PlantSpecies` (commonName, scientificName, lightNeeds, wateringInterval, soilType, humidityRange, toxicity, growthHabit, commonIssues, imageURLs)
  - `Plant` (name, dateAdded, speciesID, placementLight, placementHumidity)
  - `CareEvent` (plantID, eventType, timestamp, photoData?)
  - `CareSchedule` (plantID, lastWatered, lastFertilized, lastPruned, lastRepotted, adherenceOffset)
  - `JournalEntry` (plantID, date, healthScore, leafCount, height, notes, photoData?)
  - `EnvironmentalReading` (date, temperature, humidity, daylightHours)
- [x] Implement `PersistenceController` (or similar) wrapping `NSPersistentCloudKitContainer`
- [x] Enable CloudKit sync on the store description
- [x] Configure `allowsExternalBinaryDataStorage` on photo-bearing attributes (`CareEvent.photoData`, `JournalEntry.photoData`)

**Acceptance:**
- Store loads on app launch without errors
- Each entity can be created, fetched, updated, and deleted
- CloudKit container is configured (sync will work with a signed build)

### 0.5 Repository layer
- [x] Define `PlantRepository` protocol:
  ```swift
  protocol PlantRepository: Sendable {
      func fetchAll() async throws -> [Plant]
      func fetch(id: UUID) async throws -> Plant?
      func save(_ plant: Plant) async throws
      func delete(_ plant: Plant) async throws
  }
  ```
- [x] Define pure domain `struct` models (separate from `NSManagedObject` subclasses) for each entity
- [x] Implement `CoreDataPlantRepository` conforming to the protocol, mapping between Core Data `NSManagedObject` and domain structs
- [x] Add a `UserProfileRepository` (or extend `PlantRepository` family) for profile CRUD

**Acceptance:**
- Protocol exists and is consumed through DI (not instantiated directly)
- `CoreDataPlantRepository` passes a basic CRUD unit test

### 0.6 Dependency graph (swift-dependencies)
- [x] Register `PlantRepository` in the dependency context
- [x] Add stub registrations for future services (`WeatherService`, `AIDiagnosisProvider`) — can be unimplemented at this stage
- [x] Verify `@Dependency(\.plantRepository)` resolves in a ViewModel

**Acceptance:**
- A ViewModel can access `@Dependency(\.plantRepository)` and call it
- `withDependencies { ... }` override works in a test (inject a mock repository, verify it's used)

### 0.7 MVVM skeleton (one screen)
- [x] Create a trivial feature (e.g., a `HomeView` / placeholder dashboard) using:
  - `@Observable` ViewModel that calls `@Dependency(\.plantRepository)` to fetch plants
  - SwiftUI view that observes the ViewModel
- [x] Wire it as the app's root view

**Acceptance:**
- Screen renders in the simulator
- ViewModel can be unit-tested with a mock repository (no Core Data needed)

### 0.8 SnapshotTesting setup
- [x] Write one snapshot test (using Swift Testing's `@Suite`/`@Test` macros) for the skeleton screen with a mock ViewModel state
- [x] Verify snapshot recording and comparison workflow

**Acceptance:**
- `tuist test` runs the snapshot test and it passes
- The snapshot recording workflow is understood (`.record(mode: .on)` → switch to `.off`)

### 0.9 CI/CD (GitHub Actions with tuist)
- [x] Create `.github/workflows/ci.yml`:
  - Trigger: on push + PR
  - Setup: mise install, tuist install, tuist generate
  - Job: tuist build on iOS 26 simulator
  - Job: tuist test
  - Job: swiftlint lint
- [x] Verify CI runs green on the initial push

**Acceptance:**
- Pushing to the repo triggers CI
- CI jobs (build, test, lint) all pass

### 0.10 Kick off Workstream A — Catalog schema
- [x] Define JSON schema for the plant catalog (matching the `PlantSpecies` entity fields from 0.4)
- [x] Document the schema (field names, types, allowed values, example entry)
- [x] Begin sourcing/authoring data for the first ~10 species (enough to develop against in Phase 1)
- [x] Source/licensing decision for image references documented

**Acceptance:**
- JSON schema is defined and documented
- At least 10 species are authored in the schema (enough for Phase 1 development)
- Image source/licensing approach is documented

### 0.11 Kick off Workstream B — CoreML approach
- [x] Research options for plant detection model (B1): Create ML object detection training vs. existing CoreML models vs. model conversion
- [x] Research options for species classification model (B2): same options
- [x] Document the chosen approach for each, including data requirements, timeline estimate, and licensing
- [x] Begin acquisition/training if the approach is clear

**Acceptance:**
- A decision document (or section in PHASE_3.md) describes the chosen approach for B1 and B2
- Next steps for model acquisition/training are identified
- If training: dataset requirements and sourcing are documented
- If sourcing: candidate models are identified and licensing is checked

---

## Phase 0 Exit Criteria

All steps 0.1–0.9 must be complete. Steps 0.10 and 0.11 are "started" — their completion runs in parallel with Phases 1–3.

- [x] App builds and runs on iOS 26 simulator (`tuist build`)
- [x] CI pipeline is green (build + test + lint)
- [x] Core Data store loads; CRUD works through `PlantRepository`
- [x] `@Dependency` injection works; mock injection verified in test
- [x] One snapshot test passes
- [x] SwiftLint passes with no errors
- [x] Catalog JSON schema defined; ≥10 species authored
- [x] CoreML model approach documented for B1 and B2
