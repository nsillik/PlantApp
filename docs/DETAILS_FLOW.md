# Care Event Confirmation Flow

Improve the care action UX by replacing the current one-tap buttons with a confirmation sheet that lets users add a photo and notes before logging an event.

## Data Layer

### `Domain.swift` — CareEvent struct
- Add `var notes: String?`

### `PlantEntity.swift` — CareEventEntity
- Add `@NSManaged var notes: String?`

### `Verdigris.xcdatamodeld/contents` — CareEventEntity
- Add optional `notes` attribute (type: String)

### `PlantRepository.swift` — toDomain / fromDomain
- Map `notes` in both directions

## ViewModel (`PlantDetailViewModel`)

```swift
struct PendingCareEvent: Identifiable {
    let id: UUID
    let eventType: CareEventType
}
```

**Add:**
- `pendingEvent: PendingCareEvent?`
- `pendingEventNotes: String`
- `pendingEventPhotoData: Data?`
- `beginLogCareEvent(_ type:)` — sets up pending event, resets notes/photo
- `confirmCareEvent()` — saves event with notes + photo, clears pending state
- `cancelCareEvent()` — clears pending state

**Remove:**
- `showPhotoPicker`, `selectedPhotoItem`, `pendingPhotoData`
- `showCameraCapture`, `cameraAvailable`

## UI

### New file: `CareEventConfirmationView.swift`
A sheet with:
- Event type icon + title heading
- Photo section: when no photo selected, shows "Choose Photo" (PhotosPicker) and "Take Photo" (camera) buttons; when a photo is selected, hides the buttons and shows the photo with an "X" remove button
- Multiline notes `TextEditor`
- Confirm and Cancel buttons

### `PlantDetailView.swift`
- Remove the old photo picker / camera section
- Wire care action buttons to `beginLogCareEvent(_:)` instead of direct `logCareEvent`
- Add `.sheet(item: $viewModel.pendingEvent)` → `CareEventConfirmationView`

### `CareEventHistoryView.swift`
- Show notes caption when present on a `CareEvent`
