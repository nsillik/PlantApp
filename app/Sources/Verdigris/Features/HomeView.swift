import Dependencies
import SwiftUI

@MainActor
@Observable
final class HomeViewModel {
    var plants: [Plant] = []
    var isLoading = false
    var errorMessage: String?
    var showCatalog = false

    @ObservationIgnored
    @Dependency(\.plantRepository) private var repository

    func loadPlants() async {
        isLoading = true
        errorMessage = nil
        do {
            plants = try await repository.fetchAll()
        } catch {
            errorMessage = String(localized: "Failed to load plants.")
        }
        isLoading = false
    }

    func deletePlant(_ plant: Plant) async {
        do {
            try await repository.delete(plant)
            plants.removeAll { $0.id == plant.id }
        } catch {
            errorMessage = String(localized: "Failed to delete plant.")
        }
    }
}

struct HomeView: View {
    @State private var viewModel: HomeViewModel
    @State private var showSettings = false
    let onboardingCoordinator: OnboardingCoordinator

    init(viewModel: HomeViewModel = HomeViewModel(), onboardingCoordinator: OnboardingCoordinator) {
        self._viewModel = State(initialValue: viewModel)
        self.onboardingCoordinator = onboardingCoordinator
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView(String(localized: "Loading plants…"))
                } else if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView(
                        String(localized: "Error"),
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else if viewModel.plants.isEmpty {
                    ContentUnavailableView(
                        String(localized: "No Plants Yet"),
                        systemImage: "leaf",
                        description: Text(String(localized: "Add your first plant to get started."))
                    )
                } else {
                    List(viewModel.plants, id: \.id) { plant in
                        NavigationLink {
                            PlantDetailView(plant: plant)
                        } label: {
                            PlantRowView(plant: plant)
                        }
                        .swipeActions {
                            Button(String(localized: "Delete"), role: .destructive) {
                                Task { await viewModel.deletePlant(plant) }
                            }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "My Plants"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Add")) {
                        viewModel.showCatalog = true
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showCatalog) {
                CatalogBrowseView { _, _ in
                    viewModel.showCatalog = false
                    Task { await viewModel.loadPlants() }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView {
                    onboardingCoordinator.resetOnboarding()
                }
            }
        }
        .task {
            await viewModel.loadPlants()
        }
        .onChange(of: viewModel.showCatalog) { _, showing in
            if !showing { Task { await viewModel.loadPlants() } }
        }
    }
}

struct PlantRowView: View {
    let plant: Plant

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 44, height: 44)
                Image(systemName: "leaf")
                    .font(.title3)
                    .foregroundStyle(.green)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(plant.name)
                    .font(.headline)
                if let light = plant.placementLight?.label {
                    Text(String(localized: "\(light) light"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
