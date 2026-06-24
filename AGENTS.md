# Verdigris — Agent Guide

Verdigris is an iOS app that helps people care for their houseplants: identify plants with the camera, build personalized care plans, send adaptive reminders, and diagnose problems. See `VISION.md` for the full product vision.

## Tech Stack

- **Language:** Swift 6
- **Platform:** iOS 26.0+
- **UI:** SwiftUI with `@Observable` ViewModels (MVVM)
- **Persistence:** Core Data + CloudKit (`NSPersistentCloudKitContainer`), domain structs mapped from `NSManagedObject` in Repository layer
- **Dependency Injection:** PointFree `swift-dependencies` (`@Dependency`)
- **AI/ML:** Vision, CoreML, NaturalLanguage (on-device); optional OpenAI-compatible API
- **Testing:** Swift Testing (`@Suite`/`@Test`), PointFree `SnapshotTesting`
- **Linting:** SwiftLint
- **CI:** GitHub Actions (tests run on macOS 15 via `tuist test --device "iPhone 17 Pro"`)
- **Project generation:** Tuist (via mise)
- **Tool versioning:** mise
- **Developer team:** T9G4KUKSVP

## Architecture

```
View ──observes──► ViewModel ──calls──► Service (protocol)
                      │                      │
                      │ owns                 │ injected via
                      ▼                      ▼
                  Model (struct)       Implementation
```

- ViewModels are `@Observable` classes that own model state.
- Services are protocols, injected via `@Dependency`, making every ViewModel testable with mocks.
- Core Data is wrapped in a `Repository` pattern (`PlantRepository` protocol).
- Pure logic (care-sheet merge, scheduling engine, season matrix) lives in standalone, testable functions — not in ViewModels.

## Setup

```sh
mise install          # Install pinned tools (tuist, swiftlint)
tuist install         # Resolve SPM dependencies
tuist generate        # Generate Xcode project
```

## How to Build

```sh
tuist build
```

## How to Test

```sh
tuist test --device "iPhone 17 Pro"     # Snapshot tests (matches CI)
```

Unit tests use Swift Testing (`@Suite`/`@Test`). Snapshot tests use `SnapshotTesting`. ViewModels are tested with mock services via `withDependencies { ... }`. To regenerate snapshot references, set `RECORD_SNAPSHOTS=1` before running.

## How to Verify (Lint)

```sh
swiftlint lint
```

The command should produce **zero warnings and zero errors** (clean output). Any new lint warnings introduced by a change must be resolved before merging.

## How to Commit and Create a Pull Request

```sh
git add -A
git commit -m "feat(app): <description>"
git push
gh pr create --fill
```

- Use conventional commits with the `feat(app)` scope for all Phase 0 work.
- `gh pr create --fill` auto-populates title and body from the commit message and diff.
- Ensure PHASE_N.md, PLAN.md, and AGENTS.md are kept in sync before committing.

## Documentation as Source of Truth

This project maintains several living documents. **All of them must stay in sync with the code and with each other.** If you change code or plans, update the relevant docs in the same change.

| Document | Role | Stability |
|---|---|---|
| `VISION.md` | Product vision — what we're building and why | Stable; changes rarely |
| `PLAN.md` | Implementation plan — phase overview, scope, acceptance criteria | Mostly stable; updated when phases shift |
| `PHASE_N.md` | Per-phase detail — implementable steps and acceptance criteria | Iterated before and during implementation |
| `AGENTS.md` | This file — how to work in this project | Updated when tooling/process changes |

### Rules

1. **When you implement a step from a `PHASE_N.md`:** Mark it done (check the box) and adjust the doc if the implementation diverged from the plan.
2. **When you discover something that changes the plan:** Update `PLAN.md` and the affected `PHASE_N.md` before (or alongside) the code change.
3. **When you change the product vision:** Update `VISION.md` first, then cascade changes to `PLAN.md` and affected phase docs.
4. **When you add/change tooling, dependencies, or build process:** Update `AGENTS.md`.
5. **Never let docs and code drift.** If you're about to merge code that contradicts a doc, fix the doc in the same change.

## Key Conventions

- No inline comments in code. Doc comments (`///`) are only written on the following:
  - **ViewModels** — class purpose, property meanings, method contracts.
  - **Protocols** — purpose, method semantics (e.g. upsert vs. insert, thread-safety guarantees).
  - **Domain models** — field meanings and units where non-obvious.
  - **Protocol implementations** (actors, etc.) — a one-line summary is fine.
  - **Views** are **not** documented with doc comments; their structure should be self-evident from the SwiftUI body.
- Follow existing SwiftUI + `@Observable` patterns; do not introduce Combine or UIKit unless the plan calls for it.
- Use `@Dependency` for all service injection — never instantiate services directly in ViewModels.
- Pure logic (care-sheet merge, scheduling engine, season matrix) belongs in standalone, testable functions — not in ViewModels.
- Core Data access goes through `Repository` protocols — never call Core Data directly from a ViewModel.
- Localization uses `String(localized:)`. All user-facing strings must be localized (English + Spanish).
- Accessibility is built in: Dynamic Type, accessibility labels/hints, system colors, Dark Mode support.
