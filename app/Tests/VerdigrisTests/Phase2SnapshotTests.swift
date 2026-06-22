import Dependencies
import SnapshotTesting
import SwiftUI
import Testing

@testable import Verdigris

@MainActor
@Suite("Phase 2 Snapshot Tests")
struct Phase2SnapshotTests {
    @Test("Dashboard with today and upcoming tasks")
    func dashboardWithTasks() {
        let plant = Plant(
            id: UUID(), name: "Monstera", dateAdded: Date(),
            speciesID: UUID(), placementLight: .indirect, placementHumidity: .normal
        )
        let now = Date()
        let todayEnd = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!

        let coordinator = OnboardingCoordinator()
        let viewModel = HomeViewModel()

        viewModel.plants = [plant]
        viewModel.careTasks = [
            CareTask(id: UUID(), plantID: plant.id, plantName: "Monstera", eventType: .watered, dueDate: now, status: .incomplete),
            CareTask(id: UUID(), plantID: plant.id, plantName: "Monstera", eventType: .fertilized, dueDate: todayEnd, status: .incomplete),
            CareTask(id: UUID(), plantID: plant.id, plantName: "Monstera", eventType: .pruned, dueDate: tomorrow, status: .incomplete),
        ]

        let view = HomeView(viewModel: viewModel, onboardingCoordinator: coordinator)
        let hostingController = UIHostingController(rootView: view)

        withDependencies {
            $0.plantRepository = MockNoopPlantRepository()
            $0.catalogService = MockNoopCatalogService()
            $0.careScheduleRepository = MockNoopScheduleRepository()
            $0.careEventRepository = MockNoopEventRepository()
            $0.userProfileRepository = MockNoopProfileRepository()
        } operation: {
            withSnapshotTesting(record: SnapshotRecord.mode) {
                assertSnapshot(of: hostingController, as: .image(on: .iPhone13Pro))
            }
        }
    }

    @Test("Care event history renders")
    func careEventHistory() {
        let plantID = UUID()
        let events = [
            CareEvent(id: UUID(), plantID: plantID, eventType: .watered, timestamp: Date(), photoData: nil),
            CareEvent(id: UUID(), plantID: plantID, eventType: .fertilized, timestamp: Calendar.current.date(byAdding: .day, value: -7, to: Date())!, photoData: nil),
            CareEvent(id: UUID(), plantID: plantID, eventType: .pruned, timestamp: Calendar.current.date(byAdding: .day, value: -14, to: Date())!, photoData: nil),
            CareEvent(id: UUID(), plantID: plantID, eventType: .repotted, timestamp: Calendar.current.date(byAdding: .day, value: -30, to: Date())!, photoData: nil),
        ]

        let view = CareEventHistoryView(events: events)
        let controller = UIHostingController(rootView: view)
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 200)

        withSnapshotTesting(record: SnapshotRecord.mode) {
            assertSnapshot(of: controller, as: .image)
        }
    }
}
