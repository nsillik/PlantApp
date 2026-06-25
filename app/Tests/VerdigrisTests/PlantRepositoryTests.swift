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

        let mockRepository = MockInMemoryPlantRepository()
        try await mockRepository.save(mockPlant)

        await withDependencies {
            $0.plantRepository = mockRepository
            $0.catalogService = MockNoopCatalogService()
            $0.careScheduleRepository = MockNoopScheduleRepository()
            $0.careEventRepository = MockNoopEventRepository()
            $0.userProfileRepository = MockNoopProfileRepository()
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
