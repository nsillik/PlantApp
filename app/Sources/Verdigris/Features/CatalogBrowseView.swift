import Dependencies
import SwiftUI

@MainActor
@Observable
final class CatalogBrowseViewModel {
    var species: [PlantSpecies] = []
    var searchText = ""
    var isLoading = false
    var errorMessage: String?

    @ObservationIgnored
    @Dependency(\.catalogService) private var catalogService

    var filteredSpecies: [PlantSpecies] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return species }
        return species.filter { entry in
            let query = searchText.lowercased()
            if entry.name.localizedName.lowercased().contains(query) { return true }
            if let scientific = entry.scientificName?.lowercased(), scientific.contains(query) { return true }
            return false
        }
    }

    func loadCatalog() async {
        isLoading = true
        errorMessage = nil
        do {
            species = try await catalogService.loadCatalog()
        } catch {
            errorMessage = String(localized: "Failed to load plant catalog.")
        }
        isLoading = false
    }
}

struct CatalogBrowseView: View {
    @State private var viewModel: CatalogBrowseViewModel
    @State private var addSpecies: PlantSpecies?
    @State private var showCamera = false
    let onAdd: ((PlantSpecies, Plant) -> Void)?

    init(viewModel: CatalogBrowseViewModel = CatalogBrowseViewModel(), onAdd: ((PlantSpecies, Plant) -> Void)? = nil) {
        self._viewModel = State(initialValue: viewModel)
        self.onAdd = onAdd
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView(String(localized: "Loading catalog…"))
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView(
                        String(localized: "Error"),
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if viewModel.filteredSpecies.isEmpty {
                    ContentUnavailableView(
                        String(localized: "No Results"),
                        systemImage: "magnifyingglass",
                        description: Text(String(localized: "Try a different search term."))
                    )
                } else {
                    List(viewModel.filteredSpecies, id: \.id) { species in
                        NavigationLink {
                            CatalogSpeciesDetailView(species: species, onAdd: { selectedSpecies in
                                addSpecies = selectedSpecies
                            })
                        } label: {
                            SpeciesRowView(species: species)
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "Plant Catalog"))
            .searchable(text: $viewModel.searchText, prompt: String(localized: "Search plants…"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCamera = true
                    } label: {
                        Image(systemName: "camera")
                    }
                }
            }
        }
        .sheet(item: $addSpecies) { species in
            AddPlantView(species: species) { plant in
                onAdd?(species, plant)
                addSpecies = nil
            }
        }
        .task {
            await viewModel.loadCatalog()
        }
        .plantCameraAddFlow(isPresented: $showCamera) { plant in
            let species = viewModel.species.first { $0.id == plant.speciesID }
            if let species {
                onAdd?(species, plant)
            }
        }
    }
}

struct SpeciesRowView: View {
    let species: PlantSpecies

    var body: some View {
        ThumbnailRow(
            title: species.name.localizedName,
            subtitle: species.scientificName,
            systemImage: "leaf",
            imageColor: .green
        )
    }
}

struct CatalogSpeciesDetailView: View {
    let species: PlantSpecies
    let onAdd: (PlantSpecies) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(species.name.localizedName)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                if let scientific = species.scientificName {
                    Text(scientific)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .italic()
                }

                Divider()

                DetailRow(label: String(localized: "Light"), value: species.lightNeeds ?? String(localized: "Not specified"))
                DetailRow(label: String(localized: "Watering"), value: String(localized: "Every \(species.wateringInterval) days"))
                DetailRow(label: String(localized: "Soil"), value: species.soilType ?? String(localized: "Not specified"))
                DetailRow(label: String(localized: "Humidity"), value: species.humidityRange ?? String(localized: "Not specified"))
                DetailRow(label: String(localized: "Growth Habit"), value: species.growthHabit ?? String(localized: "Not specified"))

                if let toxicity = species.toxicity {
                    DetailRow(label: String(localized: "Toxicity"), value: toxicity)
                }

                if let issues = species.commonIssues, !issues.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "Common Issues"))
                            .font(.headline)
                        Text(issues.joined(separator: ", "))
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 24)

                Button(String(localized: "Add This Plant")) {
                    onAdd(species)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .navigationTitle(species.name.localizedName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
        }
    }
}
