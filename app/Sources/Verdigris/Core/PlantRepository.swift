import CoreData
import Dependencies
import Foundation

/// Persistence operations for the user's plants.
///
/// Conformances must be `Sendable` — implementations use an `actor` so all Core Data access
/// is isolated to a single serial executor.
protocol PlantRepository: Sendable {
    /// Returns every plant in the user's collection.
    func fetchAll() async throws -> [Plant]
    /// Returns the plant with the given identifier, or `nil` if not found.
    func fetch(id: UUID) async throws -> Plant?
    /// Creates or updates a plant. If a plant with the same `id` already exists, it is updated.
    func save(_ plant: Plant) async throws
    /// Deletes every entity matching the plant's identifier.
    func delete(_ plant: Plant) async throws
}

/// Persistence operations for the user's profile.
protocol UserProfileRepository: Sendable {
    /// Returns the user's profile, or `nil` if no profile has been saved yet.
    func fetch() async throws -> UserProfile?
    /// Creates or replaces the user's profile.
    func save(_ profile: UserProfile) async throws
}

/// Persistence operations for care schedules.
protocol CareScheduleRepository: Sendable {
    /// Returns the schedule for a given plant, or `nil` if none exists.
    func fetch(plantID: UUID) async throws -> CareSchedule?
    /// Returns all schedules.
    func fetchAll() async throws -> [CareSchedule]
    /// Creates or updates a schedule.
    func save(_ schedule: CareSchedule) async throws
    /// Persists a care event and atomically updates the schedule in a single transaction.
    func recordCareEvent(_ event: CareEvent, updatingScheduleFor plantID: UUID) async throws
    /// Returns all care events for a given plant, sorted by timestamp descending.
    func fetchCareEvents(plantID: UUID) async throws -> [CareEvent]
    /// Returns all care events across all plants since the given date.
    func fetchAllCareEvents(since date: Date) async throws -> [CareEvent]
}

/// Persistence operations for care events.
protocol CareEventRepository: Sendable {
    /// Returns all events for a given plant, sorted by timestamp descending.
    func fetch(plantID: UUID) async throws -> [CareEvent]
    /// Returns all events across all plants, sorted by timestamp descending.
    func fetchAll() async throws -> [CareEvent]
    /// Creates an event.
    func save(_ event: CareEvent) async throws
}

// MARK: - CoreData Implementations

/// Core Data-backed implementation of `PlantRepository`.
///
/// Uses `PersistenceService.withBackgroundContext` to perform all operations on a background
/// context. The `actor` isolation ensures Core Data access is serialized.
actor CoreDataPlantRepository: PlantRepository {
    private let persistenceService: PersistenceService

    init(persistenceService: PersistenceService) {
        self.persistenceService = persistenceService
    }

    func fetchAll() async throws -> [Plant] {
        try await persistenceService.fetchAll(PlantEntity.fetchRequest()).compactMap { $0.toDomain() }
    }

    func fetch(id: UUID) async throws -> Plant? {
        try await persistenceService.fetchFirst(
            PlantEntity.fetchRequest(),
            predicate: NSPredicate(format: "id == %@", id as CVarArg)
        )?.toDomain()
    }

    func save(_ plant: Plant) async throws {
        try await persistenceService.upsert(
            PlantEntity.fetchRequest(),
            predicate: NSPredicate(format: "id == %@", plant.id as CVarArg)
        ) { $0.fromDomain(plant) }
    }

    func delete(_ plant: Plant) async throws {
        try await persistenceService.deleteAll(
            PlantEntity.fetchRequest(),
            predicate: NSPredicate(format: "id == %@", plant.id as CVarArg)
        )
    }
}

/// Core Data-backed implementation of `UserProfileRepository`.
actor CoreDataUserProfileRepository: UserProfileRepository {
    private let persistenceService: PersistenceService

    init(persistenceService: PersistenceService) {
        self.persistenceService = persistenceService
    }

    func fetch() async throws -> UserProfile? {
        try await persistenceService.fetchFirst(UserProfileEntity.fetchRequest())?.toDomain()
    }

    func save(_ profile: UserProfile) async throws {
        try await persistenceService.upsert(UserProfileEntity.fetchRequest()) { $0.fromDomain(profile) }
    }
}

actor CoreDataCareScheduleRepository: CareScheduleRepository {
    private let persistenceService: PersistenceService

    init(persistenceService: PersistenceService) {
        self.persistenceService = persistenceService
    }

    func fetch(plantID: UUID) async throws -> CareSchedule? {
        try await persistenceService.fetchFirst(
            CareScheduleEntity.fetchRequest(),
            predicate: NSPredicate(format: "plantID == %@", plantID as CVarArg)
        )?.toDomain()
    }

    func fetchAll() async throws -> [CareSchedule] {
        try await persistenceService.fetchAll(CareScheduleEntity.fetchRequest()).compactMap { $0.toDomain() }
    }

    func save(_ schedule: CareSchedule) async throws {
        try await persistenceService.upsert(
            CareScheduleEntity.fetchRequest(),
            predicate: NSPredicate(format: "plantID == %@", schedule.plantID as CVarArg)
        ) { $0.fromDomain(schedule) }
    }

    func recordCareEvent(_ event: CareEvent, updatingScheduleFor plantID: UUID) async throws {
        try await persistenceService.withBackgroundContext { context in
            let eventEntity = CareEventEntity(context: context)
            eventEntity.fromDomain(event)

            let scheduleRequest = CareScheduleEntity.fetchRequest()
            scheduleRequest.predicate = NSPredicate(format: "plantID == %@", plantID as CVarArg)
            let scheduleEntities = try context.fetch(scheduleRequest)
            let scheduleEntity = scheduleEntities.first ?? CareScheduleEntity(context: context)

            var schedule = scheduleEntity.toDomain() ?? CareSchedule(
                id: scheduleEntity.id ?? UUID(),
                plantID: plantID,
                lastWatered: nil,
                lastFertilized: nil,
                lastPruned: nil,
                lastRepotted: nil,
                adherenceOffset: 0
            )
            schedule.recordEvent(event.eventType, on: event.timestamp)
            scheduleEntity.fromDomain(schedule)

            try context.save()
        }
    }

    func fetchCareEvents(plantID: UUID) async throws -> [CareEvent] {
        try await persistenceService.fetchAll(
            CareEventEntity.fetchRequest(),
            predicate: NSPredicate(format: "plantID == %@", plantID as CVarArg),
            sortDescriptors: [NSSortDescriptor(key: "timestamp", ascending: false)]
        ).compactMap { $0.toDomain() }
    }

    func fetchAllCareEvents(since date: Date) async throws -> [CareEvent] {
        try await persistenceService.fetchAll(
            CareEventEntity.fetchRequest(),
            predicate: NSPredicate(format: "timestamp >= %@", date as CVarArg),
            sortDescriptors: [NSSortDescriptor(key: "timestamp", ascending: false)]
        ).compactMap { $0.toDomain() }
    }
}

actor CoreDataCareEventRepository: CareEventRepository {
    private let persistenceService: PersistenceService

    init(persistenceService: PersistenceService) {
        self.persistenceService = persistenceService
    }

    func fetch(plantID: UUID) async throws -> [CareEvent] {
        try await persistenceService.fetchAll(
            CareEventEntity.fetchRequest(),
            predicate: NSPredicate(format: "plantID == %@", plantID as CVarArg),
            sortDescriptors: [NSSortDescriptor(key: "timestamp", ascending: false)]
        ).compactMap { $0.toDomain() }
    }

    func fetchAll() async throws -> [CareEvent] {
        try await persistenceService.fetchAll(
            CareEventEntity.fetchRequest(),
            sortDescriptors: [NSSortDescriptor(key: "timestamp", ascending: false)]
        ).compactMap { $0.toDomain() }
    }

    func save(_ event: CareEvent) async throws {
        try await persistenceService.withBackgroundContext { context in
            let entity = CareEventEntity(context: context)
            entity.fromDomain(event)
            try context.save()
        }
    }
}

// MARK: - Entity-Domain mapping

private extension PlantEntity {
    func toDomain() -> Plant? {
        guard let id, let name, let dateAdded, let speciesID else { return nil }
        return Plant(
            id: id,
            name: name,
            dateAdded: dateAdded,
            speciesID: speciesID,
            placementLight: placementLight.flatMap(LightPlacement.init(rawValue:)),
            placementHumidity: placementHumidity.flatMap(HumidityPlacement.init(rawValue:))
        )
    }

    func fromDomain(_ plant: Plant) {
        id = plant.id
        name = plant.name
        dateAdded = plant.dateAdded
        speciesID = plant.speciesID
        placementLight = plant.placementLight?.rawValue
        placementHumidity = plant.placementHumidity?.rawValue
    }
}

private extension UserProfileEntity {
    func toDomain() -> UserProfile? {
        guard let id, let city else { return nil }
        return UserProfile(
            id: id,
            city: city,
            latitude: latitude,
            longitude: longitude,
            climateClassification: ClimateClassification(rawValue: climateClassification ?? "") ?? .temperate
        )
    }

    func fromDomain(_ profile: UserProfile) {
        id = profile.id
        city = profile.city
        latitude = profile.latitude
        longitude = profile.longitude
        climateClassification = profile.climateClassification.rawValue
    }
}

private extension CareScheduleEntity {
    func toDomain() -> CareSchedule? {
        guard let id, let plantID else { return nil }
        return CareSchedule(
            id: id,
            plantID: plantID,
            lastWatered: lastWatered,
            lastFertilized: lastFertilized,
            lastPruned: lastPruned,
            lastRepotted: lastRepotted,
            adherenceOffset: Int(adherenceOffset)
        )
    }

    func fromDomain(_ schedule: CareSchedule) {
        id = schedule.id
        plantID = schedule.plantID
        lastWatered = schedule.lastWatered
        lastFertilized = schedule.lastFertilized
        lastPruned = schedule.lastPruned
        lastRepotted = schedule.lastRepotted
        adherenceOffset = Int32(schedule.adherenceOffset)
    }
}

private extension CareEventEntity {
    func toDomain() -> CareEvent? {
        guard let id, let plantID, let eventType, let timestamp else { return nil }
        let resolvedType = CareEventType(rawValue: eventType) ?? {
            reportIssue("Unknown CareEventType raw value: \(eventType)")
            return CareEventType.watered
        }()
        return CareEvent(
            id: id,
            plantID: plantID,
            eventType: resolvedType,
            timestamp: timestamp,
            photoData: photoData,
            notes: notes
        )
    }

    func fromDomain(_ event: CareEvent) {
        id = event.id
        plantID = event.plantID
        eventType = event.eventType.rawValue
        timestamp = event.timestamp
        photoData = event.photoData
        notes = event.notes
    }
}

// MARK: - Test stubs for dependency injection

struct PlantRepositoryClient: PlantRepository {
    func fetchAll() async throws -> [Plant] { reportIssue("Unimplemented"); return [] }
    func fetch(id _: UUID) async throws -> Plant? { reportIssue("Unimplemented"); return nil }
    func save(_: Plant) async throws { reportIssue("Unimplemented") }
    func delete(_: Plant) async throws { reportIssue("Unimplemented") }
}

struct UserProfileRepositoryClient: UserProfileRepository {
    func fetch() async throws -> UserProfile? { reportIssue("Unimplemented"); return nil }
    func save(_: UserProfile) async throws { reportIssue("Unimplemented") }
}

struct CareScheduleRepositoryClient: CareScheduleRepository {
    func fetch(plantID _: UUID) async throws -> CareSchedule? { reportIssue("Unimplemented"); return nil }
    func fetchAll() async throws -> [CareSchedule] { reportIssue("Unimplemented"); return [] }
    func save(_: CareSchedule) async throws { reportIssue("Unimplemented") }
    func recordCareEvent(_: CareEvent, updatingScheduleFor _: UUID) async throws { reportIssue("Unimplemented") }
    func fetchCareEvents(plantID _: UUID) async throws -> [CareEvent] { reportIssue("Unimplemented"); return [] }
    func fetchAllCareEvents(since _: Date) async throws -> [CareEvent] { reportIssue("Unimplemented"); return [] }
}

struct CareEventRepositoryClient: CareEventRepository {
    func fetch(plantID _: UUID) async throws -> [CareEvent] { reportIssue("Unimplemented"); return [] }
    func fetchAll() async throws -> [CareEvent] { reportIssue("Unimplemented"); return [] }
    func save(_: CareEvent) async throws { reportIssue("Unimplemented") }
}

struct CatalogServiceClient: CatalogService {
    func loadCatalog() async throws -> [PlantSpecies] { reportIssue("Unimplemented"); return [] }
}

struct CitySearchServiceClient: CitySearchService {
    func search(query _: String) async throws -> [CitySuggestion] { reportIssue("Unimplemented"); return [] }
    func resolve(_: CitySuggestion) async throws -> City { reportIssue("Unimplemented"); throw CitySearchError.resolutionFailed }
}

struct ClimateServiceClient: ClimateService {
    func climateClassification(for _: City) -> ClimateClassification { reportIssue("Unimplemented"); return .temperate }
}

struct NotificationSchedulerClient: NotificationScheduling {
    func requestPermission() async -> Bool { reportIssue("Unimplemented"); return false }
    func authorizationGranted() async -> Bool { reportIssue("Unimplemented"); return false }
    func registerTasks(_: [CareTask]) async { reportIssue("Unimplemented") }
    func removeAll() { reportIssue("Unimplemented") }
}
