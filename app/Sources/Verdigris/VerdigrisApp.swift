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
    }
}

struct OnboardingRootView: View {
    @State var coordinator: OnboardingCoordinator
    @State private var showCatalog = false

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
                }
                .padding()
                .sheet(isPresented: $showCatalog) {
                    CatalogBrowseView { _, _ in
                        showCatalog = false
                        Task { await coordinator.saveProfileAndComplete() }
                    }
                }
            case .complete:
                HomeView(onboardingCoordinator: coordinator)
            }
        }
    }
}
