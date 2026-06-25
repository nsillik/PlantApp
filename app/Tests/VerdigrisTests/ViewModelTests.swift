import Dependencies
import Foundation
import Testing

@testable import Verdigris

@Suite("ViewModel Tests")
struct ViewModelTests {
    let testSpecies = PlantSpecies(
        id: UUID(),
        name: PlantName(commonNamesLocalized: ["en": "Monstera", "es": "Monstera"]),
        scientificName: "Monstera deliciosa",
        lightNeeds: "bright indirect",
        wateringInterval: 7,
        soilType: "Well-draining potting mix"
    )

    @Test("LiveClimateService returns temperate for latitudes >= 30°")
    func climateTemperate() {
        let service = LiveClimateService()
        #expect(service.climateClassification(for: City(name: "", region: "", latitude: 30, longitude: 0)) == .temperate)
        #expect(service.climateClassification(for: City(name: "", region: "", latitude: 45, longitude: 0)) == .temperate)
        #expect(service.climateClassification(for: City(name: "", region: "", latitude: -90, longitude: 0)) == .temperate)
    }

    @Test("LiveClimateService returns arid for latitudes 15..<30°")
    func climateArid() {
        let service = LiveClimateService()
        #expect(service.climateClassification(for: City(name: "", region: "", latitude: 15, longitude: 0)) == .arid)
        #expect(service.climateClassification(for: City(name: "", region: "", latitude: 20, longitude: 0)) == .arid)
        #expect(service.climateClassification(for: City(name: "", region: "", latitude: 29.9, longitude: 0)) == .arid)
        #expect(service.climateClassification(for: City(name: "", region: "", latitude: -29.9, longitude: 0)) == .arid)
    }

    @Test("LiveClimateService returns tropical for latitudes 0..<15°")
    func climateTropical() {
        let service = LiveClimateService()
        #expect(service.climateClassification(for: City(name: "", region: "", latitude: 0, longitude: 0)) == .tropical)
        #expect(service.climateClassification(for: City(name: "", region: "", latitude: 10, longitude: 0)) == .tropical)
        #expect(service.climateClassification(for: City(name: "", region: "", latitude: 14.9, longitude: 0)) == .tropical)
        #expect(service.climateClassification(for: City(name: "", region: "", latitude: -14.9, longitude: 0)) == .tropical)
    }

    @Test("CatalogBrowseViewModel loads and filters species")
    func catalogBrowse() async {
        let mockService = MockCatalogService(species: [testSpecies])
        let viewModel = await withDependencies {
            $0.catalogService = mockService
        } operation: {
            await MainActor.run { CatalogBrowseViewModel() }
        }

        await viewModel.loadCatalog()
        await MainActor.run {
            #expect(viewModel.species.count == 1)
            #expect(viewModel.filteredSpecies.count == 1)
        }

        await MainActor.run {
            viewModel.searchText = "zzz"
        }
        await MainActor.run {
            #expect(viewModel.filteredSpecies.isEmpty)
        }

        await MainActor.run {
            viewModel.searchText = ""
        }
        await MainActor.run {
            #expect(viewModel.filteredSpecies.count == 1)
        }
    }

    @Test("CatalogBrowseViewModel shows error on failure")
    func catalogBrowseError() async {
        let mockService = FailingCatalogService()
        let viewModel = await withDependencies {
            $0.catalogService = mockService
        } operation: {
            await MainActor.run { CatalogBrowseViewModel() }
        }

        await viewModel.loadCatalog()
        await MainActor.run {
            #expect(viewModel.errorMessage != nil)
            #expect(viewModel.species.isEmpty)
        }
    }

    @Test("AddPlantViewModel saves with custom name")
    func addPlantWithCustomName() async {
        let mockRepo = MockAddPlantRepository()
        let viewModel = await withDependencies {
            $0.plantRepository = mockRepo
        } operation: {
            await MainActor.run { AddPlantViewModel(species: testSpecies) }
        }

        await MainActor.run {
            viewModel.customName = "My Monstera"
        }
        let plant = await viewModel.savePlant()
        await MainActor.run {
            #expect(plant != nil)
            #expect(plant?.name == "My Monstera")
            #expect(plant?.speciesID == testSpecies.id)
        }
        let savedPlants = (try? await mockRepo.fetchAll()) ?? []
        #expect(savedPlants.count == 1)
    }

    @Test("AddPlantViewModel defaults to species name when custom name is empty")
    func addPlantDefaultName() async {
        let mockRepo = MockAddPlantRepository()
        let viewModel = await withDependencies {
            $0.plantRepository = mockRepo
        } operation: {
            await MainActor.run { AddPlantViewModel(species: testSpecies) }
        }

        let plant = await viewModel.savePlant()
        await MainActor.run {
            #expect(plant?.name == "Monstera")
        }
    }
}
