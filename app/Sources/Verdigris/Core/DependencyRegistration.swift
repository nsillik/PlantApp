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
}

private enum PersistenceServiceKey: DependencyKey {
    static let liveValue: PersistenceService = PersistenceController.shared
    static let testValue: PersistenceService = PersistenceController.inMemory()
}

private enum PlantRepositoryKey: DependencyKey {
    static let liveValue: PlantRepository = CoreDataPlantRepository(
        persistenceService: PersistenceController.shared
    )

    static let testValue: PlantRepository = UnimplementedPlantRepository()
}

private enum CatalogServiceKey: DependencyKey {
    static let liveValue: CatalogService = BundleCatalogService()
    static let testValue: CatalogService = UnimplementedCatalogService()
}

private struct UnimplementedCatalogService: CatalogService {
    func loadCatalog() async throws -> [PlantSpecies] {
        reportIssue("Unimplemented")
        return []
    }
}

private enum CitySearchServiceKey: DependencyKey {
    static let liveValue: CitySearchService = {
        MainActor.assumeIsolated { MapKitCitySearchService() }
    }()
    static let testValue: CitySearchService = UnimplementedCitySearchService()
}

private struct UnimplementedCitySearchService: CitySearchService {
    func search(query: String) async throws -> [CitySuggestion] {
        reportIssue("Unimplemented")
        throw CitySearchError.notFound
    }

    func resolve(_ suggestion: CitySuggestion) async throws -> City {
        reportIssue("Unimplemented")
        throw CitySearchError.resolutionFailed
    }
}

private enum ClimateServiceKey: DependencyKey {
    static let liveValue: ClimateService = LiveClimateService()
    static let testValue: ClimateService = UnimplementedClimateService()
}

private struct UnimplementedClimateService: ClimateService {
    func climateClassification(for city: City) -> ClimateClassification {
        reportIssue("Unimplemented")
        return .temperate
    }
}

private enum UserProfileRepositoryKey: DependencyKey {
    static let liveValue: UserProfileRepository = CoreDataUserProfileRepository(
        persistenceService: PersistenceController.shared
    )

    static let testValue: UserProfileRepository = UnimplementedUserProfileRepository()
}

private struct UnimplementedPlantRepository: PlantRepository {
    func fetchAll() async throws -> [Plant] {
        reportIssue("Unimplemented")
        return []
    }

    func fetch(id: UUID) async throws -> Plant? {
        reportIssue("Unimplemented")
        return nil
    }

    func save(_ plant: Plant) async throws {
        reportIssue("Unimplemented")
    }

    func delete(_ plant: Plant) async throws {
        reportIssue("Unimplemented")
    }
}

private struct UnimplementedUserProfileRepository: UserProfileRepository {
    func fetch() async throws -> UserProfile? {
        reportIssue("Unimplemented")
        return nil
    }

    func save(_ profile: UserProfile) async throws {
        reportIssue("Unimplemented")
    }
}
