# Phase 2 — Scheduling, Reminders, Care Log

**Goal:** The app becomes daily-useful: adaptive reminders fire, user logs care with one tap, dashboard shows what's due.

**Depends on:** Phase 1.

**Back in:** [PLAN.md](PLAN.md)

---

## Steps

### 2.1 CareSchedule model
- [ ] Domain model: `CareSchedule` (plantID, lastWatered: Date?, lastFertilized: Date?, lastPruned: Date?, lastRepotted: Date?, adherenceOffset: TimeInterval)
- [ ] Core Data entity (already in schema from Phase 0) — wire to domain model
- [ ] Repository methods for fetching/updating schedule per plant

**Acceptance:**
- Schedule persists per plant
- Tracks last event date per care type
- Adherence offset is stored and updatable

### 2.2 Scheduling engine (pure function)
- [ ] Implement: `func nextDueDates(schedule: CareSchedule, careSheet: CareSheet, season: Season, now: Date) -> [CareTask]`
- [ ] `CareTask`: type (water/fertilize/prune/repot), dueDate, isOverdue
- [ ] Adjustment factors:
  - Base interval from `CareSheet` (which already accounts for placement + season)
  - Adherence: if user consistently logs events N days late, extend interval by ~N/2
  - Season: re-evaluate day length from latitude + current month (already in care sheet, but scheduler confirms)
- [ ] Same function usable from both the app and future widget (no app-instance dependencies)

**Acceptance:**
- Unit tests cover:
  - Baseline next-due calculation (no prior events → interval from care sheet)
  - Overdue detection (last event + interval < now)
  - Adherence adjustment (simulate late logging → interval extends)
  - Multiple care types (water + fertilize + prune coexist)
- Output is deterministic: same inputs → same `[CareTask]`
- Function has no dependency on app state, singletons, or Core Data

### 2.3 Care event logging
- [ ] `CareEvent` domain model (plantID, type, timestamp, photoData?)
- [ ] Log from plant detail: buttons for Water / Fertilize / Prune / Repot
- [ ] Log from dashboard quick-action (see 2.4)
- [ ] On log: update `CareSchedule.lastX`, recompute next due dates, re-register notifications

**Acceptance:**
- User can log each care type from plant detail
- Event persists in Core Data
- Schedule updates immediately after logging
- Timestamp defaults to now (editable in future; not required for Phase 2)

### 2.4 Dashboard with due tasks
- [ ] "Today" section: overdue tasks + tasks due today, grouped by plant
- [ ] "Upcoming" section: next 7 days of tasks
- [ ] Quick-action buttons per due task (e.g., "Watered" tap → logs event, task disappears)
- [ ] Pull to refresh (re-runs scheduling engine)
- [ ] Runs scheduling engine on appear and after each care event

**Acceptance:**
- Dashboard shows correct due/upcoming tasks across all plants
- Quick-action logging works and updates the list immediately
- Empty state when no tasks are due
- Scheduling engine runs on appear (not just on event log)

### 2.5 Notification registration
- [ ] Implement `NotificationScheduler` that registers `UNNotificationRequest` with calendar triggers
- [ ] Registration strategy (64-cap prioritization):
  - Register only the soonest reminder per plant per care type
  - On fire, re-register the next one for that plant/type
  - Cap total at 60 (safety margin under iOS 64 limit)
- [ ] Re-register on:
  - App launch (`scenePhase` becomes active)
  - Schedule change (care event logged → scheduling engine output changes)
- [ ] Request notification permission on first relevant user action (not on app launch)

**Acceptance:**
- Notifications are registered with correct trigger dates
- 64-cap strategy works: with 20+ plants, only soonest-per-plant is registered
- Firing a notification triggers re-registration of the next one
- Re-registration on launch doesn't duplicate notifications (dedup by identifier)
- Permission request is contextual, not aggressive

### 2.6 Care event history
- [ ] Per-plant timeline of past care events (chronological, most recent first)
- [ ] Each entry: type icon, date, optional photo thumbnail
- [ ] Filterable by care type (optional — nice to have)

**Acceptance:**
- History shows all logged events for the plant in order
- Photo thumbnails load quickly (thumbnail generated at capture time per VISION.md)
- Tapping a photo entry shows full-resolution image

### 2.7 Photo attachment for care events
- [ ] `PhotosPicker` for selecting existing photo, camera option for new photo
- [ ] Compress to JPEG (~500KB target) before storing
- [ ] Store via `allowsExternalBinaryDataStorage` (configured in Phase 0)
- [ ] Generate thumbnail at capture time for list/timeline views
- [ ] Full-resolution loaded on demand

**Acceptance:**
- User can attach a photo when logging a care event (optional)
- Photo persists and syncs via CloudKit
- Thumbnails load instantly in lists; full image loads on demand
- Storage doesn't bloat the main Core Data store (external binary storage)

---

## Phase 2 Exit Criteria

- [ ] Scheduling engine produces correct next-due dates from all adjustment factors
- [ ] User can log care events from dashboard and plant detail
- [ ] Dashboard shows correct due and upcoming tasks
- [ ] Notifications fire at correct times; 64-cap strategy verified at 20+ plants
- [ ] Notifications re-register on launch and after schedule changes (no duplicates)
- [ ] Care event history shows logged events chronologically per plant
- [ ] User can attach photos to care events; photos persist and sync
- [ ] Scheduling engine has comprehensive unit tests
- [ ] Snapshot tests pass for dashboard (with tasks) and care event history
- [ ] All user-facing strings localized (EN + ES)

→ **MVP candidate A:** If Phase 3 slips, the app is already a useful product here.
