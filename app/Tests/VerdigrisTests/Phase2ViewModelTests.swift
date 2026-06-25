import Dependencies
import Foundation
import Testing

@testable import Verdigris

@MainActor
@Suite("Phase 2 ViewModel Tests")
struct Phase2ViewModelTests {
    let testPlantID = UUID()
    let testSpeciesID = UUID()

    var testSpecies: PlantSpecies {
        PlantSpecies(
            id: testSpeciesID,
            name: PlantName(commonNamesLocalized: ["en": "Monstera"]),
            wateringInterval: 7,
            fertilizingInterval: 30,
            pruningInterval: 90,
            repottingInterval: 365
        )
    }

    var testPlant: Plant {
        Plant(
            id: testPlantID,
            name: "Living Room Monstera",
            dateAdded: Date(),
            speciesID: testSpeciesID,
            placementLight: .indirect,
            placementHumidity: .normal
        )
    }

    @Test("logCareEvent saves event and updates schedule")
    func logCareEventSavesEvent() async throws {
        let scheduleRepo = MockInMemoryScheduleRepository()
        let catalog = MockInMemoryCatalogService(species: [testSpecies])
        let plantRepo = MockInMemoryPlantRepository()
        try await plantRepo.save(testPlant)

        let viewModel = await withDependencies {
            $0.plantRepository = plantRepo
            $0.catalogService = catalog
            $0.careScheduleRepository = scheduleRepo
            $0.userProfileRepository = MockNoopProfileRepository()
            $0.notificationScheduling = MockNoopNotificationScheduler()
        } operation: {
            HomeViewModel()
        }

        await viewModel.loadAll()

        await viewModel.logCareEvent(plantID: testPlantID, eventType: .watered)

        let events = try await scheduleRepo.fetchCareEvents(plantID: testPlantID)
        #expect(events.count == 1)
        #expect(events.first?.eventType == .watered)

        let schedule = try await scheduleRepo.fetch(plantID: testPlantID)
        #expect(schedule?.lastWatered != nil)
        #expect(viewModel.isLogging == false)
    }

    @Test("logCareEvent marks task as completed after recompute")
    func logCareEventMarksTaskCompleted() async throws {
        let scheduleRepo = MockInMemoryScheduleRepository()
        let catalog = MockInMemoryCatalogService(species: [testSpecies])
        let plantRepo = MockInMemoryPlantRepository()
        try await plantRepo.save(testPlant)

        let viewModel = await withDependencies {
            $0.plantRepository = plantRepo
            $0.catalogService = catalog
            $0.careScheduleRepository = scheduleRepo
            $0.userProfileRepository = MockNoopProfileRepository()
            $0.notificationScheduling = MockNoopNotificationScheduler()
        } operation: {
            HomeViewModel()
        }

        await viewModel.loadAll()

        await viewModel.logCareEvent(plantID: testPlantID, eventType: .watered)

        let wateredTask = viewModel.careTasks.first { $0.eventType == .watered }
        #expect(wateredTask?.status == .completed)
    }

    @Test("confirmCareEvent saves event and updates schedule")
    func confirmCareEventSavesEvent() async throws {
        let scheduleRepo = MockInMemoryScheduleRepository()

        let viewModel = await withDependencies {
            $0.plantRepository = MockNoopPlantRepository()
            $0.catalogService = MockInMemoryCatalogService(species: [testSpecies])
            $0.careScheduleRepository = scheduleRepo
            $0.userProfileRepository = MockNoopProfileRepository()
        } operation: {
            await MainActor.run { PlantDetailViewModel(plant: testPlant) }
        }

        await viewModel.loadData()
        viewModel.beginLogCareEvent(.watered)
        viewModel.pendingEventNotes = "Good soak"
        await viewModel.confirmCareEvent()

        #expect(viewModel.pendingEvent == nil)
        #expect(viewModel.pendingEventNotes.isEmpty)
        #expect(viewModel.careEvents.count == 1)
        #expect(viewModel.careEvents.first?.eventType == .watered)
        #expect(viewModel.careEvents.first?.notes == "Good soak")

        let events = try await scheduleRepo.fetchCareEvents(plantID: testPlantID)
        #expect(events.count == 1)
        #expect(events.first?.eventType == .watered)

        let schedule = try await scheduleRepo.fetch(plantID: testPlantID)
        #expect(schedule?.lastWatered != nil)
    }

    @Test("cancelCareEvent clears pending state")
    func cancelCareEventClearsState() async {
        let viewModel = withDependencies {
            $0.plantRepository = MockNoopPlantRepository()
            $0.catalogService = MockInMemoryCatalogService()
            $0.careScheduleRepository = MockNoopScheduleRepository()
            $0.careEventRepository = MockNoopEventRepository()
            $0.userProfileRepository = MockNoopProfileRepository()
        } operation: {
            PlantDetailViewModel(plant: testPlant)
        }

        viewModel.beginLogCareEvent(.fertilized)
        viewModel.pendingEventNotes = "Some notes"
        viewModel.cancelCareEvent()

        #expect(viewModel.pendingEvent == nil)
        #expect(viewModel.pendingEventNotes.isEmpty)
        #expect(viewModel.pendingEventPhotoData == nil)
    }

    @Test("NotificationScheduling protocol is injectable via @Dependency")
    func notificationSchedulingInjectable() async {
        await withDependencies {
            $0.notificationScheduling = MockNoopNotificationScheduler()
        } operation: {
            @Dependency(\.notificationScheduling) var scheduler
            let granted = await scheduler.requestPermission()
            #expect(granted == false)
            await scheduler.registerTasks([])
            scheduler.removeAll()
        }
    }
}
