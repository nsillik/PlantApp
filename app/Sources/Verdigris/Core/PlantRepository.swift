import CoreData
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
        try await persistenceService.withBackgroundContext { context in
            let request = PlantEntity.fetchRequest()
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toDomain() }
        }
    }

    func fetch(id: UUID) async throws -> Plant? {
        try await persistenceService.withBackgroundContext { context in
            let request = PlantEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            let entities = try context.fetch(request)
            return entities.first?.toDomain()
        }
    }

    func save(_ plant: Plant) async throws {
        try await persistenceService.withBackgroundContext { context in
            let request = PlantEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", plant.id as CVarArg)
            let entities = try context.fetch(request)
            let entity = entities.first ?? PlantEntity(context: context)
            entity.fromDomain(plant)
            try context.save()
        }
    }

    func delete(_ plant: Plant) async throws {
        try await persistenceService.withBackgroundContext { context in
            let request = PlantEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", plant.id as CVarArg)
            let entities = try context.fetch(request)
            for entity in entities {
                context.delete(entity)
            }
            try context.save()
        }
    }
}

/// Core Data-backed implementation of `UserProfileRepository`.
actor CoreDataUserProfileRepository: UserProfileRepository {
    private let persistenceService: PersistenceService

    init(persistenceService: PersistenceService) {
        self.persistenceService = persistenceService
    }

    func fetch() async throws -> UserProfile? {
        try await persistenceService.withBackgroundContext { context in
            let request = UserProfileEntity.fetchRequest()
            let entities = try context.fetch(request)
            return entities.first?.toDomain()
        }
    }

    func save(_ profile: UserProfile) async throws {
        try await persistenceService.withBackgroundContext { context in
            let request = UserProfileEntity.fetchRequest()
            let entities = try context.fetch(request)
            let entity = entities.first ?? UserProfileEntity(context: context)
            entity.fromDomain(profile)
            try context.save()
        }
    }
}

actor CoreDataCareScheduleRepository: CareScheduleRepository {
    private let persistenceService: PersistenceService

    init(persistenceService: PersistenceService) {
        self.persistenceService = persistenceService
    }

    func fetch(plantID: UUID) async throws -> CareSchedule? {
        try await persistenceService.withBackgroundContext { context in
            let request = CareScheduleEntity.fetchRequest()
            request.predicate = NSPredicate(format: "plantID == %@", plantID as CVarArg)
            let entities = try context.fetch(request)
            return entities.first?.toDomain()
        }
    }

    func fetchAll() async throws -> [CareSchedule] {
        try await persistenceService.withBackgroundContext { context in
            let request = CareScheduleEntity.fetchRequest()
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toDomain() }
        }
    }

    func save(_ schedule: CareSchedule) async throws {
        try await persistenceService.withBackgroundContext { context in
            let request = CareScheduleEntity.fetchRequest()
            request.predicate = NSPredicate(format: "plantID == %@", schedule.plantID as CVarArg)
            let entities = try context.fetch(request)
            let entity = entities.first ?? CareScheduleEntity(context: context)
            entity.fromDomain(schedule)
            try context.save()
        }
    }
}

actor CoreDataCareEventRepository: CareEventRepository {
    private let persistenceService: PersistenceService

    init(persistenceService: PersistenceService) {
        self.persistenceService = persistenceService
    }

    func fetch(plantID: UUID) async throws -> [CareEvent] {
        try await persistenceService.withBackgroundContext { context in
            let request = CareEventEntity.fetchRequest()
            request.predicate = NSPredicate(format: "plantID == %@", plantID as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toDomain() }
        }
    }

    func fetchAll() async throws -> [CareEvent] {
        try await persistenceService.withBackgroundContext { context in
            let request = CareEventEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            let entities = try context.fetch(request)
            return entities.compactMap { $0.toDomain() }
        }
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
        return CareEvent(
            id: id,
            plantID: plantID,
            eventType: CareEventType(rawValue: eventType) ?? .watered,
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
