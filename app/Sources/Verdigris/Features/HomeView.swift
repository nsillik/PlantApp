import Dependencies
import SwiftUI

/// State and actions for the home screen — the app's root view.
@MainActor
@Observable
final class HomeViewModel {
    /// Plants loaded from the repository.
    var plants: [Plant] = []
    /// Whether a `loadPlants` call is in flight.
    var isLoading = false
    /// A user-presentable error message, or `nil` when there is no error.
    var errorMessage: String?

    @ObservationIgnored
    @Dependency(\.plantRepository) private var repository

    func loadPlants() async {
        isLoading = true
        errorMessage = nil
        do {
            plants = try await repository.fetchAll()
        } catch {
            errorMessage = "Failed to load plants: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func deletePlant(_ plant: Plant) async {
        do {
            try await repository.delete(plant)
            plants.removeAll { $0.id == plant.id }
        } catch {
            errorMessage = "Failed to delete plant: \(error.localizedDescription)"
        }
    }
}

/// The app's root view, rendering the plant list (or an empty / loading / error state).
///
/// `loadPlants()` is called automatically on appear unless `autoLoad` is set to `false`,
/// which snapshot tests use to avoid triggering async work.
struct HomeView: View {
    @State private var viewModel: HomeViewModel
    private let autoLoad: Bool

    init(viewModel: HomeViewModel = HomeViewModel(), autoLoad: Bool = true) {
        self._viewModel = State(initialValue: viewModel)
        self.autoLoad = autoLoad
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
                        VStack(alignment: .leading) {
                            Text(plant.name)
                                .font(.headline)
                            Text(String(localized: "Added \(plant.dateAdded.formatted(date: .abbreviated, time: .omitted))"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button(String(localized: "Delete"), role: .destructive) {
                                Task { await viewModel.deletePlant(plant) }
                            }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "Verdigris"))
        }
        .task {
            guard autoLoad else { return }
            await viewModel.loadPlants()
        }
    }
}

#Preview {
    HomeView()
}
