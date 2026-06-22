import Foundation
import Dependencies
import Testing

@testable import Verdigris

@Suite("PlantRepository Tests")
struct PlantRepositoryTests {
    @Test("Mock repository can be injected and used")
    func mockRepositoryInjection() async {
        let mockPlant = Plant(
            id: UUID(),
            name: "Test Monstera",
            dateAdded: Date(),
            speciesID: UUID(),
            placementLight: .indirect,
            placementHumidity: .normal
        )

        let mockRepository = MockPlantRepository()
        await mockRepository.addPlant(mockPlant)

        await withDependencies {
            $0.plantRepository = mockRepository
            $0.catalogService = MockPlantTestCatalogService()
            $0.careScheduleRepository = MockPlantTestScheduleRepository()
            $0.careEventRepository = MockPlantTestEventRepository()
            $0.userProfileRepository = MockPlantTestProfileRepository()
        } operation: {
            let viewModel = await MainActor.run { HomeViewModel() }
            await viewModel.loadAll()
            await MainActor.run {
                #expect(viewModel.plants.count == 1)
                #expect(viewModel.plants.first?.name == "Test Monstera")
            }
        }
    }
}

actor MockPlantRepository: PlantRepository {
    private var storage: [Plant] = []

    func addPlant(_ plant: Plant) {
        storage.append(plant)
    }

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

private struct MockPlantTestCatalogService: CatalogService {
    func loadCatalog() async throws -> [PlantSpecies] { [] }
}

private struct MockPlantTestScheduleRepository: CareScheduleRepository {
    func fetch(plantID: UUID) async throws -> CareSchedule? { nil }
    func fetchAll() async throws -> [CareSchedule] { [] }
    func save(_ schedule: CareSchedule) async throws {}
}

private struct MockPlantTestEventRepository: CareEventRepository {
    func fetch(plantID: UUID) async throws -> [CareEvent] { [] }
    func fetchAll() async throws -> [CareEvent] { [] }
    func save(_ event: CareEvent) async throws {}
}

private struct MockPlantTestProfileRepository: UserProfileRepository {
    func fetch() async throws -> UserProfile? { nil }
    func save(_ profile: UserProfile) async throws {}
}
