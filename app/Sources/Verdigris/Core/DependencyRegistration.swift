import Dependencies
import Foundation

extension DependencyValues {
    var persistenceService: PersistenceService {
        get { self[PersistenceServiceKey.self] }
        set { self[PersistenceServiceKey.self] = newValue }
    }

    var plantRepository: PlantRepository {
        get { self[PlantRepositoryKey.self] }
        set { self[PlantRepositoryKey.self] = newValue }
    }

    var userProfileRepository: UserProfileRepository {
        get { self[UserProfileRepositoryKey.self] }
        set { self[UserProfileRepositoryKey.self] = newValue }
    }

    var catalogService: CatalogService {
        get { self[CatalogServiceKey.self] }
        set { self[CatalogServiceKey.self] = newValue }
    }

    var citySearchService: CitySearchService {
        get { self[CitySearchServiceKey.self] }
        set { self[CitySearchServiceKey.self] = newValue }
    }

    var climateService: ClimateService {
        get { self[ClimateServiceKey.self] }
        set { self[ClimateServiceKey.self] = newValue }
    }

    var careScheduleRepository: CareScheduleRepository {
        get { self[CareScheduleRepositoryKey.self] }
        set { self[CareScheduleRepositoryKey.self] = newValue }
    }

    var careEventRepository: CareEventRepository {
        get { self[CareEventRepositoryKey.self] }
        set { self[CareEventRepositoryKey.self] = newValue }
    }

    var notificationScheduling: NotificationScheduling {
        get { self[NotificationSchedulingKey.self] }
        set { self[NotificationSchedulingKey.self] = newValue }
    }

    var plantIdentificationService: PlantIdentificationService {
        get { self[PlantIdentificationServiceKey.self] }
        set { self[PlantIdentificationServiceKey.self] = newValue }
    }
}

private enum PersistenceServiceKey: DependencyKey {
    static let liveValue: PersistenceService = PersistenceController.shared
    static let testValue: PersistenceService = PersistenceController.inMemory()
}

private enum PlantRepositoryKey: DependencyKey {
    static let liveValue: PlantRepository = CoreDataPlantRepository(
        persistenceService: PersistenceController.shared
    )
    static let testValue: PlantRepository = PlantRepositoryClient()
}

private enum CatalogServiceKey: DependencyKey {
    static let liveValue: CatalogService = BundleCatalogService()
    static let testValue: CatalogService = CatalogServiceClient()
}

private enum CitySearchServiceKey: DependencyKey {
    static let liveValue: CitySearchService = {
        MainActor.assumeIsolated { MapKitCitySearchService() }
    }()
    static let testValue: CitySearchService = CitySearchServiceClient()
}

private enum ClimateServiceKey: DependencyKey {
    static let liveValue: ClimateService = LiveClimateService()
    static let testValue: ClimateService = ClimateServiceClient()
}

private enum UserProfileRepositoryKey: DependencyKey {
    static let liveValue: UserProfileRepository = CoreDataUserProfileRepository(
        persistenceService: PersistenceController.shared
    )
    static let testValue: UserProfileRepository = UserProfileRepositoryClient()
}

private enum CareScheduleRepositoryKey: DependencyKey {
    static let liveValue: CareScheduleRepository = CoreDataCareScheduleRepository(
        persistenceService: PersistenceController.shared
    )
    static let testValue: CareScheduleRepository = CareScheduleRepositoryClient()
}

private enum CareEventRepositoryKey: DependencyKey {
    static let liveValue: CareEventRepository = CoreDataCareEventRepository(
        persistenceService: PersistenceController.shared
    )
    static let testValue: CareEventRepository = CareEventRepositoryClient()
}

private enum NotificationSchedulingKey: DependencyKey {
    static let liveValue: NotificationScheduling = NotificationScheduler()
    static let testValue: NotificationScheduling = NotificationSchedulerClient()
}

private enum PlantIdentificationServiceKey: DependencyKey {
    static let liveValue: PlantIdentificationService = CoreMLPlantIdentificationService()
    static let testValue: PlantIdentificationService = MockPlantIdentificationService()
}
