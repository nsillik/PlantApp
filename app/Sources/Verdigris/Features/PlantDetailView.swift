import Dependencies
import SwiftUI

@MainActor
@Observable
final class PlantDetailViewModel {
    var plant: Plant
    var catalogSpecies: PlantSpecies?
    var userProfile: UserProfile?
    var careSheet: CareSheet?

    @ObservationIgnored
    @Dependency(\.plantRepository) private var repository
    @ObservationIgnored
    @Dependency(\.userProfileRepository) private var profileRepository
    @ObservationIgnored
    @Dependency(\.catalogService) private var catalogService

    var editableName: String {
        get { plant.name }
        set { plant.name = newValue }
    }

    init(plant: Plant) {
        self.plant = plant
    }

    func loadData() async {
        do {
            let allSpecies = try await catalogService.loadCatalog()
            catalogSpecies = allSpecies.first { $0.id == plant.speciesID }
            userProfile = try await profileRepository.fetch()
            regenerateCareSheet()
        } catch {}
    }

    func updatePlacement(light: LightPlacement) {
        plant.placementLight = light
        regenerateCareSheet()
        Task { try? await repository.save(plant) }
    }

    func updatePlacement(humidity: HumidityPlacement) {
        plant.placementHumidity = humidity
        regenerateCareSheet()
        Task { try? await repository.save(plant) }
    }

    func updateName(_ name: String) {
        plant.name = name
        Task { try? await repository.save(plant) }
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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

                Divider()

                Text(String(localized: "Placement"))
                    .font(.title2)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 12) {
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

                Divider()

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
            .padding()
        }
        .task {
            await viewModel.loadData()
        }
    }
}
