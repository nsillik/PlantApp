import Dependencies
import PhotosUI
import SwiftUI

struct PendingCareEvent: Identifiable {
    let id: UUID
    let eventType: CareEventType
}

@MainActor
@Observable
final class PlantDetailViewModel {
    var plant: Plant
    var catalogSpecies: PlantSpecies?
    var userProfile: UserProfile?
    var careSheet: CareSheet?
    var careEvents: [CareEvent] = []
    var isLoadingEvents = false
    var errorMessage: String?
    var pendingEvent: PendingCareEvent?
    var pendingEventNotes: String = ""
    var pendingEventPhotoData: Data?

    @ObservationIgnored
    @Dependency(\.plantRepository) private var repository
    @ObservationIgnored
    @Dependency(\.userProfileRepository) private var profileRepository
    @ObservationIgnored
    @Dependency(\.catalogService) private var catalogService
    @ObservationIgnored
    @Dependency(\.careScheduleRepository) private var scheduleRepository

    var editableName: String {
        get { plant.name }
        set { plant.name = newValue }
    }

    init(plant: Plant) {
        self.plant = plant
    }

    func loadData() async {
        do {
            async let allSpecies = catalogService.loadCatalog()
            async let profile = profileRepository.fetch()
            async let events = scheduleRepository.fetchCareEvents(plantID: plant.id)

            catalogSpecies = try await allSpecies.first { $0.id == plant.speciesID }
            userProfile = try await profile
            careEvents = try await events
            regenerateCareSheet()
        } catch {
            reportIssue("""
              Failed to load plant detail data for \(plant.id): \
              \(error.localizedDescription)
              """)
        }
    }

    func updatePlacement(light: LightPlacement) {
        Task {
            var updated = plant
            updated.placementLight = light
            do {
                try await repository.save(updated)
                plant = updated
                regenerateCareSheet()
            } catch {
                errorMessage = "Failed to save light placement."
            }
        }
    }

    func updatePlacement(humidity: HumidityPlacement) {
        Task {
            var updated = plant
            updated.placementHumidity = humidity
            do {
                try await repository.save(updated)
                plant = updated
                regenerateCareSheet()
            } catch {
                errorMessage = "Failed to save humidity placement."
            }
        }
    }

    func updateName(_ name: String) {
        Task {
            var updated = plant
            updated.name = name
            do {
                try await repository.save(updated)
                plant = updated
            } catch {
                errorMessage = "Failed to save plant name."
            }
        }
    }

    func beginLogCareEvent(_ type: CareEventType) {
        pendingEvent = PendingCareEvent(id: UUID(), eventType: type)
        pendingEventNotes = ""
        pendingEventPhotoData = nil
    }

    func confirmCareEvent() async {
        guard let currentPending = pendingEvent else { return }

        let event = CareEvent(
            id: currentPending.id,
            plantID: plant.id,
            eventType: currentPending.eventType,
            timestamp: Date(),
            photoData: pendingEventPhotoData,
            notes: pendingEventNotes.isEmpty ? nil : pendingEventNotes
        )

        do {
            try await scheduleRepository.recordCareEvent(event, updatingScheduleFor: plant.id)
            careEvents.insert(event, at: 0)
            self.pendingEvent = nil
            pendingEventPhotoData = nil
            pendingEventNotes = ""
        } catch {
            errorMessage = "Failed to log care event."
        }
    }

    func cancelCareEvent() {
        pendingEvent = nil
        pendingEventNotes = ""
        pendingEventPhotoData = nil
    }

    func loadPhoto(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let compressed = compressImage(data, targetSizeKB: 500)
        pendingEventPhotoData = compressed
    }

    func handleCameraCapture(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let compressed = compressImage(data, targetSizeKB: 500)
        pendingEventPhotoData = compressed
    }

    private func compressImage(_ data: Data, targetSizeKB: Int) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let targetBytes = targetSizeKB * 1024
        var compression: CGFloat = 0.8
        var compressed = image.jpegData(compressionQuality: compression) ?? data
        while compressed.count > targetBytes && compression > 0.1 {
            compression -= 0.1
            compressed = image.jpegData(compressionQuality: compression) ?? data
        }
        return compressed
    }

    private func regenerateCareSheet() {
        guard let species = catalogSpecies, let profile = userProfile,
              let light = plant.placementLight, let humidity = plant.placementHumidity else {
            careSheet = nil
            return
        }
        let season = Season.current(latitude: profile.latitude)
        careSheet = generateCareSheet(
            species: species,
            user: profile,
            light: light,
            humidity: humidity,
            season: season
        )
    }
}

struct PlantDetailView: View {
    @State private var viewModel: PlantDetailViewModel

    init(plant: Plant) {
        self._viewModel = State(initialValue: PlantDetailViewModel(plant: plant))
    }

    init(viewModel: PlantDetailViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
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
        .task {
            await viewModel.loadData()
        }
        .sheet(item: $viewModel.pendingEvent) { pendingEvent in
            CareEventConfirmationView(viewModel: viewModel, pendingEvent: pendingEvent)
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        TextField(String(localized: "Plant Name"), text: Binding(
            get: { viewModel.editableName },
            set: { viewModel.updateName($0) }
        ))
        .font(.largeTitle)
        .fontWeight(.bold)
        .textFieldStyle(.plain)

        if let species = viewModel.catalogSpecies {
            Text(species.name.localizedName)
                .font(.headline)
                .foregroundStyle(.secondary)
            if let scientific = species.scientificName {
                Text(scientific)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
    }

    private var careActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Care Actions"))
                .font(.title2)
                .fontWeight(.semibold)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(CareEventType.allCases, id: \.self) { eventType in
                    CareActionButton(
                        title: eventType.localizedLabel,
                        icon: eventType.systemImage,
                        color: eventType.tint
                    ) {
                        viewModel.beginLogCareEvent(eventType)
                    }
                }
            }
        }
    }

    private var placementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Placement"))
                .font(.title2)
                .fontWeight(.semibold)
            Text(String(localized: "Light"))
                .font(.headline)
            Picker(String(localized: "Light"), selection: Binding(
                get: { viewModel.plant.placementLight ?? .indirect },
                set: { viewModel.updatePlacement(light: $0) }
            )) {
                ForEach(LightPlacement.allCases, id: \.self) { placement in
                    Text(placement.label).tag(placement)
                }
            }
            .pickerStyle(.segmented)

            Text(String(localized: "Humidity"))
                .font(.headline)
            Picker(String(localized: "Humidity"), selection: Binding(
                get: { viewModel.plant.placementHumidity ?? .normal },
                set: { viewModel.updatePlacement(humidity: $0) }
            )) {
                ForEach(HumidityPlacement.allCases, id: \.self) { placement in
                    Text(placement.label).tag(placement)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var careGuideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Care Guide"))
                .font(.title2)
                .fontWeight(.semibold)
            if let careSheet = viewModel.careSheet {
                CareSheetView(careSheet: careSheet)
            } else {
                ContentUnavailableView(
                    String(localized: "Loading…"),
                    systemImage: "leaf",
                    description: Text(String(localized: "Generating your care guide."))
                )
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Care History"))
                .font(.title2)
                .fontWeight(.semibold)
            CareEventHistoryView(events: viewModel.careEvents)
        }
    }
}

private struct CareActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
