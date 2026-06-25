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
            $0.plantRepository = MockNoopPlantRepository()
            $0.catalogService = MockNoopCatalogService()
            $0.careScheduleRepository = MockNoopScheduleRepository()
            $0.careEventRepository = MockNoopEventRepository()
            $0.userProfileRepository = MockNoopProfileRepository()
            $0.notificationScheduling = MockNoopNotificationScheduler()
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
            $0.plantRepository = MockNoopPlantRepository()
            $0.catalogService = MockNoopCatalogService()
            $0.careScheduleRepository = MockNoopScheduleRepository()
            $0.careEventRepository = MockNoopEventRepository()
            $0.userProfileRepository = MockNoopProfileRepository()
            $0.notificationScheduling = MockNoopNotificationScheduler()
        } operation: {
            withSnapshotTesting(record: SnapshotRecord.mode) {
                assertSnapshot(of: hostingController, as: .image(on: .iPhone13Pro))
            }
        }
    }
}
