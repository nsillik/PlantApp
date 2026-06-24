import Dependencies
import Foundation
import Testing

@testable import Verdigris

@MainActor
@Suite("PlantIdentificationService label resolution")
struct PlantIdentificationServiceTests {
    /// Confirmed label should resolve to the *catalog's* `PlantSpecies` (real care
    /// fields), not a synthetic stub fabricated from the model-label JSON.
    @Test("resolveModelLabel returns the catalog's PlantSpecies and real care fields")
    func resolveModelLabelJoinsToCatalog() async {
        let monsteraID = UUID(uuidString: "a1b2c3d4-e5f6-7890-abcd-ef1234567890")!
        let monstera = PlantSpecies(
            id: monsteraID,
            name: PlantName(commonNamesLocalized: ["en": "Monstera", "es": "Monstera"]),
            scientificName: "Monstera deliciosa",
            wateringInterval: 7,
            fertilizingInterval: 21,
            toxicity: "Mildly toxic to pets"
        )
        let catalog = MockInMemoryCatalogService(species: [monstera])

        let service = withDependencies {
            $0.catalogService = catalog
        } operation: {
            CoreMLPlantIdentificationService(labelToCatalogID: ["monstera_deliciosa": monsteraID])
        }

        let resolved = await service.resolveModelLabel("monstera_deliciosa")
        #expect(resolved?.id == monsteraID)
        #expect(resolved?.scientificName == "Monstera deliciosa")
        #expect(resolved?.wateringInterval == 7)
        #expect(resolved?.toxicity == "Mildly toxic to pets")
    }

    @Test("resolveModelLabel returns nil for unknown labels")
    func resolveModelLabelReturnsNilForUnknownLabel() async {
        let monsteraID = UUID()
        let catalog = MockInMemoryCatalogService(species: [
            PlantSpecies(id: monsteraID, name: PlantName(commonNamesLocalized: ["en": "Monstera"]), wateringInterval: 7)
        ])

        let service = withDependencies {
            $0.catalogService = catalog
        } operation: {
            CoreMLPlantIdentificationService(labelToCatalogID: ["monstera_deliciosa": monsteraID])
        }

        #expect(await service.resolveModelLabel("definitely_not_a_label") == nil)
    }

    @Test("resolveModelLabel returns nil when the mapped catalog ID is missing from the catalog")
    func resolveModelLabelReturnsNilWhenIDMissingFromCatalog() async {
        let orphanID = UUID()
        let catalog = MockInMemoryCatalogService(species: [])  // empty on purpose

        let service = withDependencies {
            $0.catalogService = catalog
        } operation: {
            CoreMLPlantIdentificationService(labelToCatalogID: ["orphan_label": orphanID])
        }

        #expect(await service.resolveModelLabel("orphan_label") == nil)
    }

    @Test("resolveModelLabel caches: subsequent calls do not re-hit the catalog service")
    func resolveModelLabelCaches() async throws {
        let monsteraID = UUID()
        let monstera = PlantSpecies(
            id: monsteraID,
            name: PlantName(commonNamesLocalized: ["en": "Monstera"]),
            wateringInterval: 7
        )
        let countingCatalog = CountingCatalogService(catalog: [monstera])

        let service = withDependencies {
            $0.catalogService = countingCatalog
        } operation: {
            CoreMLPlantIdentificationService(labelToCatalogID: ["monstera_deliciosa": monsteraID])
        }

        _ = await service.resolveModelLabel("monstera_deliciosa")
        _ = await service.resolveModelLabel("monstera_deliciosa")
        _ = await service.resolveModelLabel("monstera_deliciosa")

        let calls = await countingCatalog.loadCatalogCalls
        #expect(calls == 1)
    }
}

private actor CountingCatalogService: CatalogService {
    private let catalog: [PlantSpecies]
    private(set) var loadCatalogCalls = 0

    init(catalog: [PlantSpecies]) {
        self.catalog = catalog
    }

    func loadCatalog() async throws -> [PlantSpecies] {
        loadCatalogCalls += 1
        return catalog
    }
}
