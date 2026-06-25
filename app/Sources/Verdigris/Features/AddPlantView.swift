import Dependencies
import SwiftUI

/// Form-state VM for "AddPlantView": owns the in-flight species (so the camera
/// re-identify path can swap it mid-form), the custom name, the light/humidity
/// placement pickers, and the synchronous save call against `PlantRepository`.
/// On success `savePlant()` returns the persisted `Plant` for the caller to
/// route to detail/navigation; on failure it sets `errorMessage` and returns nil.
@MainActor
@Observable
final class AddPlantViewModel {
    var species: PlantSpecies
    var customName = ""
    var selectedLight: LightPlacement = .indirect
    var selectedHumidity: HumidityPlacement = .normal
    var isSaving = false
    var errorMessage: String?

    @ObservationIgnored
    @Dependency(\.plantRepository) private var repository

    init(species: PlantSpecies) {
        self.species = species
    }

    func savePlant() async -> Plant? {
        isSaving = true
        errorMessage = nil
        let name = customName.trimmingCharacters(in: .whitespaces).isEmpty
            ? species.name.localizedName
            : customName.trimmingCharacters(in: .whitespaces)

        let plant = Plant(
            id: UUID(),
            name: name,
            dateAdded: Date(),
            speciesID: species.id,
            placementLight: selectedLight,
            placementHumidity: selectedHumidity
        )

        do {
            try await repository.save(plant)
            isSaving = false
            return plant
        } catch {
            errorMessage = String(localized: "Failed to save plant.")
            isSaving = false
            return nil
        }
    }
}

struct AddPlantView: View {
    @State private var viewModel: AddPlantViewModel
    @State private var showCamera = false
    let onSaved: (Plant) -> Void
    @Environment(\.dismiss) private var dismiss

    init(species: PlantSpecies, onSaved: @escaping (Plant) -> Void) {
        self._viewModel = State(initialValue: AddPlantViewModel(species: species))
        self.onSaved = onSaved
    }

    init(viewModel: AddPlantViewModel, onSaved: @escaping (Plant) -> Void) {
        self._viewModel = State(initialValue: viewModel)
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "Plant Name")) {
                    TextField(String(localized: "Custom name (optional)"), text: $viewModel.customName)
                }

                Section(String(localized: "Light Placement")) {
                    Picker(String(localized: "Light"), selection: $viewModel.selectedLight) {
                        ForEach(LightPlacement.allCases, id: \.self) { placement in
                            Text(placement.label).tag(placement)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section(String(localized: "Humidity")) {
                    Picker(String(localized: "Humidity"), selection: $viewModel.selectedHumidity) {
                        ForEach(HumidityPlacement.allCases, id: \.self) { placement in
                            Text(placement.label).tag(placement)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button(String(localized: "Save Plant")) {
                        Task {
                            guard let plant = await viewModel.savePlant() else { return }
                            onSaved(plant)
                            dismiss()
                        }
                    }
                    .disabled(viewModel.isSaving)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(String(localized: "Add \(viewModel.species.name.localizedName)"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCamera = true
                    } label: {
                        Image(systemName: "camera")
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                PlantCameraView(
                    onSpeciesConfirmed: { identifiedSpecies in
                        viewModel.species = identifiedSpecies
                        showCamera = false
                    },
                    onDismiss: {
                        showCamera = false
                    }
                )
            }
        }
    }
}
