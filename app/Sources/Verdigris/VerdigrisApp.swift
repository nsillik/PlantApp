import Dependencies
import SwiftUI

@main
struct VerdigrisApp: App {
    @Dependency(\.persistenceService) private var persistenceService
    @State private var coordinator = OnboardingCoordinator()

    var body: some Scene {
        WindowGroup {
            if coordinator.hasCompletedOnboarding {
                HomeView(onboardingCoordinator: coordinator)
                    .environment(\.managedObjectContext, persistenceService.viewContext)
            } else {
                OnboardingRootView(coordinator: coordinator)
                    .environment(\.managedObjectContext, persistenceService.viewContext)
            }
        }
        .onChange(of: coordinator.hasCompletedOnboarding) { _, _ in
            if coordinator.hasCompletedOnboarding {
                Task {
                    @Dependency(\.notificationScheduling) var scheduler
                    _ = await scheduler.requestPermission()
                }
            }
        }
    }
}

struct OnboardingRootView: View {
    @State var coordinator: OnboardingCoordinator
    @State private var showCatalog = false
    @State private var showCamera = false
    @State private var cameraSpecies: PlantSpecies?

    var body: some View {
        Group {
            switch coordinator.currentStep {
            case .location:
                LocationOnboardingView { profile in
                    coordinator.completeLocation(profile)
                }
            case .addFirstPlant:
                VStack(spacing: 16) {
                    Text(String(localized: "Add Your First Plant"))
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text(String(localized: "Browse the catalog and choose a plant to add."))
                        .foregroundStyle(.secondary)

                    Button(String(localized: "Browse Catalog")) {
                        showCatalog = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(String(localized: "Identify with Camera")) {
                        showCamera = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding()
                .sheet(isPresented: $showCatalog) {
                    CatalogBrowseView { _, _ in
                        showCatalog = false
                        Task { await coordinator.saveProfileAndComplete() }
                    }
                }
                .fullScreenCover(isPresented: $showCamera) {
                    CameraView(
                        onSpeciesConfirmed: { species in
                            cameraSpecies = species
                            showCamera = false
                        },
                        onDismiss: {
                            showCamera = false
                        }
                    )
                }
                .sheet(item: $cameraSpecies) { species in
                    AddPlantView(species: species) { plant in
                        cameraSpecies = nil
                        Task { await coordinator.saveProfileAndComplete() }
                    }
                }
            case .complete:
                HomeView(onboardingCoordinator: coordinator)
            }
        }
    }
}
