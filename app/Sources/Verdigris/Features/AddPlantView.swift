import Dependencies
import SwiftUI

@MainActor
@Observable
final class AddPlantViewModel {
    var customName = ""
    var selectedLight: LightPlacement = .indirect
    var selectedHumidity: HumidityPlacement = .normal
    var isSaving = false
    var errorMessage: String?

    @ObservationIgnored
    @Dependency(\.plantRepository) private var repository

    func savePlant(species: PlantSpecies) async -> Plant? {
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
    @State var species: PlantSpecies
    let onSaved: (Plant) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AddPlantViewModel()
    @State private var showCamera = false

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "Plant Name")) {
                    TextField(String(localized: "Custom name (optional)"), text: $viewModel.customName)
                }

                Section(String(localized: "Light Placement")) {
                    Picker(String(localized: "Light"), selection: $viewModel.selectedLight) {
                        Text(LightPlacement.indirect.label).tag(LightPlacement.indirect)
                        Text(LightPlacement.directSouth.label).tag(LightPlacement.directSouth)
                        Text(LightPlacement.directEastWest.label).tag(LightPlacement.directEastWest)
                    }
                    .pickerStyle(.menu)
                }

                Section(String(localized: "Humidity")) {
                    Picker(String(localized: "Humidity"), selection: $viewModel.selectedHumidity) {
                        Text(HumidityPlacement.dry.label).tag(HumidityPlacement.dry)
                        Text(HumidityPlacement.normal.label).tag(HumidityPlacement.normal)
                        Text(HumidityPlacement.wet.label).tag(HumidityPlacement.wet)
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
                            guard let plant = await viewModel.savePlant(species: species) else { return }
                            onSaved(plant)
                            dismiss()
                        }
                    }
                    .disabled(viewModel.isSaving)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(String(localized: "Add \(species.name.localizedName)"))
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
                CameraView(
                    onSpeciesConfirmed: { identifiedSpecies in
                        species = identifiedSpecies
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
