import SwiftUI

/// View modifier that owns the "identify with camera → choose plant → save" flow.
///
/// Lifecycle: while `isPresented` is true it presents `PlantCameraView` as a
/// full-screen cover. When the camera confirms a species the cover is dismissed
/// first; only after dismissal does the internal state mutate to present the
/// pre-existing `AddPlantView` as a sheet. After `AddPlantView` saves its plant,
/// its sheet dismisses and `onSaved` is delivered *after* that sheet has gone —
/// this sequenced hand-off eliminates the chained-sheet dismiss/present races
/// that arise when callers chain `fullScreenCover` + multiple sheets manually.
struct PlantCameraFlow: ViewModifier {
    @Binding var isPresented: Bool
    let onSaved: (Plant) -> Void

    @State private var confirmedSpecies: PlantSpecies?
    @State private var pendingSpecies: PlantSpecies?
    @State private var pendingPlant: Plant?

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $isPresented) {
                PlantCameraView(
                    onSpeciesConfirmed: { species in
                        pendingSpecies = species
                        isPresented = false
                    },
                    onDismiss: {
                        isPresented = false
                    }
                )
            }
            .onChange(of: isPresented) { _, shown in
                if !shown, let pending = pendingSpecies {
                    confirmedSpecies = pending
                    pendingSpecies = nil
                }
            }
            .sheet(item: $confirmedSpecies) { species in
                AddPlantView(species: species) { plant in
                    pendingPlant = plant
                    confirmedSpecies = nil
                }
            }
            .onChange(of: confirmedSpecies) { _, species in
                if species == nil, let plant = pendingPlant {
                    pendingPlant = nil
                    onSaved(plant)
                }
            }
    }
}

extension View {
    /// Presents the AI-assisted plant camera full-screen; after the user
    /// identifies and saves a plant, `onSaved` runs once both the camera cover
    /// and the add-plant sheet have fully dismissed (see `PlantCameraFlow`).
    func plantCameraAddFlow(
        isPresented: Binding<Bool>,
        onSaved: @escaping (Plant) -> Void
    ) -> some View {
        modifier(PlantCameraFlow(isPresented: isPresented, onSaved: onSaved))
    }
}
