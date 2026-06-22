import Dependencies
import SnapshotTesting
import SwiftUI
import Testing

@testable import Verdigris

@MainActor
@Suite("HomeView Snapshot Tests")
struct HomeViewSnapshotTests {
    @Test("Empty state renders correctly")
    func emptyState() {
        let coordinator = OnboardingCoordinator()
        let view = HomeView(onboardingCoordinator: coordinator)
        let hostingController = UIHostingController(rootView: view)
        withDependencies {
            $0.plantRepository = MockSnapshotPlantRepository()
        } operation: {
            withSnapshotTesting(record: .missing) {
                assertSnapshot(of: hostingController, as: .image(on: .iPhone13Pro))
            }
        }
    }

    @Test("Loading state renders correctly")
    func loadingState() {
        let coordinator = OnboardingCoordinator()
        let viewModel = HomeViewModel()
        viewModel.isLoading = true
        let view = HomeView(viewModel: viewModel, autoLoad: false, onboardingCoordinator: coordinator)
        let hostingController = UIHostingController(rootView: view)
        withDependencies {
            $0.plantRepository = MockSnapshotPlantRepository()
        } operation: {
            withSnapshotTesting(record: .missing) {
                assertSnapshot(of: hostingController, as: .image(on: .iPhone13Pro))
            }
        }
    }
}

private struct MockSnapshotPlantRepository: PlantRepository {
    func fetchAll() async throws -> [Plant] { [] }
    func fetch(id: UUID) async throws -> Plant? { nil }
    func save(_ plant: Plant) async throws {}
    func delete(_ plant: Plant) async throws {}
}
