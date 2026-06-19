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
