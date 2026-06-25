import Foundation

@testable import Verdigris

// MARK: - No-op mocks (for snapshot tests and any test needing inert dependencies)

struct MockNoopPlantRepository: PlantRepository {
    func fetchAll() async throws -> [Plant] { [] }
    func fetch(id: UUID) async throws -> Plant? { nil }
    func save(_ plant: Plant) async throws {}
    func delete(_ plant: Plant) async throws {}
}

struct MockNoopNotificationScheduler: NotificationScheduling {
    func requestPermission() async -> Bool { false }
    func authorizationGranted() async -> Bool { false }
    func registerTasks(_ tasks: [CareTask]) async {}
    func removeAll() {}
}

struct MockNoopCatalogService: CatalogService {
    func loadCatalog() async throws -> [PlantSpecies] { [] }
}

struct MockNoopScheduleRepository: CareScheduleRepository {
    func fetch(plantID: UUID) async throws -> CareSchedule? { nil }
    func fetchAll() async throws -> [CareSchedule] { [] }
    func save(_ schedule: CareSchedule) async throws {}
}

struct MockNoopEventRepository: CareEventRepository {
    func fetch(plantID: UUID) async throws -> [CareEvent] { [] }
    func fetchAll() async throws -> [CareEvent] { [] }
    func save(_ event: CareEvent) async throws {}
}

struct MockNoopProfileRepository: UserProfileRepository {
    func fetch() async throws -> UserProfile? { nil }
    func save(_ profile: UserProfile) async throws {}
}

// MARK: - Functional mocks (for ViewModel integration tests)

actor MockInMemoryPlantRepository: PlantRepository {
    private var storage: [Plant] = []

    func fetchAll() async throws -> [Plant] {
        storage
    }

    func fetch(id: UUID) async throws -> Plant? {
        storage.first { $0.id == id }
    }

    func save(_ plant: Plant) async throws {
        storage.removeAll { $0.id == plant.id }
        storage.append(plant)
    }

    func delete(_ plant: Plant) async throws {
        storage.removeAll { $0.id == plant.id }
    }
}

actor MockInMemoryScheduleRepository: CareScheduleRepository {
    private var storage: [CareSchedule] = []

    func fetch(plantID: UUID) async throws -> CareSchedule? {
        storage.first { $0.plantID == plantID }
    }

    func fetchAll() async throws -> [CareSchedule] {
        storage
    }

    func save(_ schedule: CareSchedule) async throws {
        storage.removeAll { $0.plantID == schedule.plantID }
        storage.append(schedule)
    }
}

actor MockInMemoryEventRepository: CareEventRepository {
    private var storage: [CareEvent] = []

    func fetch(plantID: UUID) async throws -> [CareEvent] {
        storage.filter { $0.plantID == plantID }.sorted { $0.timestamp > $1.timestamp }
    }

    func fetchAll() async throws -> [CareEvent] {
        storage.sorted { $0.timestamp > $1.timestamp }
    }

    func save(_ event: CareEvent) async throws {
        storage.append(event)
    }
}

actor MockInMemoryCatalogService: CatalogService {
    private var storage: [PlantSpecies] = []

    init(species: [PlantSpecies] = []) {
        self.storage = species
    }

    func loadCatalog() async throws -> [PlantSpecies] {
        storage
    }
}

actor MockCatalogService: CatalogService {
    private let species: [PlantSpecies]

    init(species: [PlantSpecies]) {
        self.species = species
    }

    func loadCatalog() async throws -> [PlantSpecies] {
        species
    }
}

actor FailingCatalogService: CatalogService {
    func loadCatalog() async throws -> [PlantSpecies] {
        throw CatalogError.fileNotFound
    }
}

actor MockAddPlantRepository: PlantRepository {
    private var storage: [Plant] = []

    func fetchAll() async throws -> [Plant] { storage }
    func fetch(id: UUID) async throws -> Plant? { storage.first { $0.id == id } }

    func save(_ plant: Plant) async throws {
        storage.removeAll { $0.id == plant.id }
        storage.append(plant)
    }

    func delete(_ plant: Plant) async throws {
        storage.removeAll { $0.id == plant.id }
    }
}
