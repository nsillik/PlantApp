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
            $0.catalogService = MockSnapshotCatalogService()
            $0.careScheduleRepository = MockSnapshotScheduleRepository()
            $0.careEventRepository = MockSnapshotEventRepository()
            $0.userProfileRepository = MockSnapshotProfileRepository()
        } operation: {
            withSnapshotTesting(record: SnapshotRecord.mode) {
                assertSnapshot(of: hostingController, as: .image(on: .iPhone13Pro))
            }
        }
    }

    @Test("Loading state renders correctly")
    func loadingState() {
        let coordinator = OnboardingCoordinator()
        let viewModel = HomeViewModel()
        viewModel.isLoading = true
        let view = HomeView(viewModel: viewModel, onboardingCoordinator: coordinator)
        let hostingController = UIHostingController(rootView: view)
        withDependencies {
            $0.plantRepository = MockSnapshotPlantRepository()
            $0.catalogService = MockSnapshotCatalogService()
            $0.careScheduleRepository = MockSnapshotScheduleRepository()
            $0.careEventRepository = MockSnapshotEventRepository()
            $0.userProfileRepository = MockSnapshotProfileRepository()
        } operation: {
            withSnapshotTesting(record: SnapshotRecord.mode) {
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

private struct MockSnapshotCatalogService: CatalogService {
    func loadCatalog() async throws -> [PlantSpecies] { [] }
}

private struct MockSnapshotScheduleRepository: CareScheduleRepository {
    func fetch(plantID: UUID) async throws -> CareSchedule? { nil }
    func fetchAll() async throws -> [CareSchedule] { [] }
    func save(_ schedule: CareSchedule) async throws {}
}

private struct MockSnapshotEventRepository: CareEventRepository {
    func fetch(plantID: UUID) async throws -> [CareEvent] { [] }
    func fetchAll() async throws -> [CareEvent] { [] }
    func save(_ event: CareEvent) async throws {}
}

private struct MockSnapshotProfileRepository: UserProfileRepository {
    func fetch() async throws -> UserProfile? { nil }
    func save(_ profile: UserProfile) async throws {}
}
