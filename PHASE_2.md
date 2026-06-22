# Phase 2 — Scheduling, Reminders, Care Log

**Goal:** The app becomes daily-useful: adaptive reminders fire, user logs care with one tap, dashboard shows what's due.

**Depends on:** Phase 1.

**Back in:** [PLAN.md](PLAN.md)

---

## Steps

### 2.1 CareSchedule model
- [x] Domain model: `CareSchedule` (plantID, lastWatered: Date?, lastFertilized: Date?, lastPruned: Date?, lastRepotted: Date?, adherenceOffset: Int)
- [x] Core Data entity `CareScheduleEntity` (already in schema from Phase 0) — wired to domain model via `toDomain`/`fromDomain` in `PlantRepository.swift`
- [x] `CareScheduleRepository` protocol + `CoreDataCareScheduleRepository` implementation + DI registration in `DependencyRegistration.swift`
- [x] `CareEventRepository` protocol + `CoreDataCareEventRepository` implementation + DI registration
- [x] `CareEventEntity` `toDomain`/`fromDomain` mapping (already implemented)

Numeric interval sources:
- `PlantSpecies.wateringInterval` from catalog (already exists)
- `PlantSpecies.fertilizingInterval`, `pruningInterval`, `repottingInterval` added to catalog schema and all 15 species in catalog.json
- Scheduling engine reads intervals directly from `PlantSpecies`
- Season/adherence adjustments applied in the `SchedulingEngine`

**Acceptance:**
- [x] Schedule persists per plant
- [x] Tracks last event date per care type
- [x] Adherence offset is stored and updatable
- [x] `CareScheduleRepository` and `CareEventRepository` are injectable via `@Dependency`

### 2.2 Scheduling engine (pure function)
- [x] Implement: `func nextDueDates(schedule: CareSchedule, species: PlantSpecies, careSheet: CareSheet, season: Season, now: Date) -> [CareTask]`
- [x] `CareTask` domain model (plantID, eventType: CareEventType, dueDate, isOverdue) added to `Domain.swift`
- [x] Base intervals available from:
  - Watering: `PlantSpecies.wateringInterval`
  - Fertilizing: `PlantSpecies.fertilizingInterval` (from catalog)
  - Pruning: `PlantSpecies.pruningInterval` (from catalog)
  - Repotting: `PlantSpecies.repottingInterval` (from catalog)
- [x] Adjustment factors:
  - Base interval from catalog
  - Season: winter extends watering, summer shortens
  - Adherence: if user consistently logs events N days late, extend interval by ~N/2
- [x] Same function usable from both the app and future widget (no app-instance dependencies)

**Acceptance:**
- [x] Unit tests cover:
  - Baseline next-due calculation (no prior events → interval from species)
  - Overdue detection (last event + interval < now)
  - Adherence adjustment (simulate late logging → interval extends)
  - Multiple care types (water + fertilize + prune coexist)
- [x] Output is deterministic: same inputs → same `[CareTask]` (excluding UUID ids)
- [x] Function has no dependency on app state, singletons, or Core Data

### 2.3 Care event logging
- [x] `CareEvent` domain model (plantID, type, timestamp, photoData?)
- [x] Log from plant detail: buttons for Water / Fertilize / Prune / Repot
- [x] Log from dashboard quick-action (see 2.4)
- [x] On log: update `CareSchedule.lastX` via `CareScheduleRepository`, recompute next due dates, re-register notifications

**Acceptance:**
- [x] User can log each care type from plant detail
- [x] Event persists in Core Data
- [x] Schedule updates immediately after logging
- [x] Timestamp defaults to now (editable in future; not required for Phase 2)

### 2.4 Dashboard with due tasks
- [x] "Today" section: overdue tasks + tasks due today, grouped by plant
- [x] "Upcoming" section: next 7 days of tasks
- [x] Quick-action buttons per due task (e.g., "Done" tap → logs event, task disappears)
- [x] Pull to refresh (re-runs scheduling engine)
- [x] Runs scheduling engine on appear and after each care event

**Acceptance:**
- [x] Dashboard shows correct due/upcoming tasks across all plants
- [x] Quick-action logging works and updates the list immediately
- [x] Empty state when no tasks are due
- [x] Scheduling engine runs on appear (not just on event log)

### 2.5 Notification registration
- [x] Implement `NotificationScheduler` that registers `UNNotificationRequest` with calendar triggers
- [x] Registration strategy (64-cap prioritization):
   - Register the 60 soonest tasks globally across all plants and care types
   - On fire, re-register the next soonest task for the same plant/care type
   - Cap total at 60 (safety margin under iOS 64 limit)
- [x] Re-register on:
  - App launch (onboarding completion triggers permission + registration)
  - Schedule change (care event logged → scheduling engine output changes)
- [x] Request notification permission on first relevant user action (contextual alert)

**Acceptance:**
- [x] Notifications are registered with correct trigger dates
- [x] 64-cap strategy implemented (max 60 pending requests)
- [x] Re-registration removes stale notifications and adds new ones (dedup by identifier)
- [x] Permission request is contextual (alert asking user post-onboarding)

### 2.6 Care event history
- [x] Per-plant timeline of past care events (chronological, most recent first)
- [x] Each entry: type icon, date, optional photo thumbnail
- [x] Filterable by care type (optional — nice to have — not implemented)

**Acceptance:**
- [x] History shows all logged events for the plant in order
- [x] Photo thumbnails load quickly (thumbnail generated at capture time)
- [ ] Tapping a photo entry shows full-resolution image (not implemented — shows thumbnail inline)

### 2.7 Photo attachment for care events
- [x] `PhotosPicker` for selecting existing photo
- [ ] Camera option for new photo (not implemented — PhotosPicker only)
- [x] Compress to JPEG (~500KB target) before storing
- [x] Store via `allowsExternalBinaryDataStorage` (configured in Phase 0)
- [x] Generate thumbnail at capture time for list/timeline views
- [ ] Full-resolution loaded on demand (not implemented — stores compressed version only)

**Acceptance:**
- [x] User can attach a photo when logging a care event (optional)
- [x] Photo persists and syncs via CloudKit
- [x] Thumbnails load instantly in lists
- [x] Storage doesn't bloat the main Core Data store (external binary storage)

---

## Phase 2 Exit Criteria

- [x] Scheduling engine produces correct next-due dates from all adjustment factors
- [x] User can log care events from dashboard and plant detail
- [x] Dashboard shows correct due and upcoming tasks
- [x] Notifications registered with 60-cap strategy implemented
- [x] Notifications re-register on launch and after schedule changes (no duplicates)
- [x] Care event history shows logged events chronologically per plant
- [x] User can attach photos to care events; photos persist
- [x] Scheduling engine has comprehensive unit tests (6 tests)
- [x] Snapshot tests pass for dashboard (with tasks) and care event history
- [x] All user-facing strings localized (EN + ES)

→ **MVP candidate A:** If Phase 3 slips, the app is already a useful product here.
