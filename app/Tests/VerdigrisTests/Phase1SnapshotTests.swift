import Dependencies
import SnapshotTesting
import SwiftUI
import Testing

@testable import Verdigris

@MainActor
@Suite("Phase 1 Snapshot Tests")
struct Phase1SnapshotTests {
    let testSpecies = PlantSpecies(
        id: UUID(),
        name: PlantName(commonNamesLocalized: ["en": "Monstera", "es": "Monstera"]),
        scientificName: "Monstera deliciosa",
        lightNeeds: "bright indirect",
        wateringInterval: 7,
        soilType: "Well-draining potting mix",
        humidityRange: "medium-high",
        toxicity: "moderate",
        growthHabit: "climbing",
        commonIssues: ["yellow leaves", "brown edges", "root rot"],
        imageURLs: []
    )

    @Test("Catalog species detail renders")
    func catalogSpeciesDetail() {
        let view = CatalogSpeciesDetailView(species: testSpecies, onAdd: { _ in })
        let controller = UIHostingController(rootView: view)
        withSnapshotTesting(record: .missing) {
            assertSnapshot(of: controller, as: .image(on: .iPhone13Pro))
        }
    }

    @Test("Care sheet renders for indirect light, dry, winter")
    func careSheetIndirectDryWinter() {
        let user = UserProfile(
            id: UUID(), city: "Chicago", latitude: 41.9, longitude: -87.6,
            climateClassification: .temperate
        )
        let sheet = generateCareSheet(
            species: testSpecies, user: user,
            light: .indirect, humidity: .dry, season: .winter
        )
        let view = CareSheetView(careSheet: sheet)
        let controller = UIHostingController(rootView: view)
        withSnapshotTesting(record: .missing) {
            assertSnapshot(of: controller, as: .image(on: .iPhone13Pro))
        }
    }

    @Test("Care sheet renders for south-facing, normal, summer")
    func careSheetSouthNormalSummer() {
        let user = UserProfile(
            id: UUID(), city: "Phoenix", latitude: 33.4, longitude: -112.0,
            climateClassification: .arid
        )
        let sheet = generateCareSheet(
            species: testSpecies, user: user,
            light: .directSouth, humidity: .normal, season: .summer
        )
        let view = CareSheetView(careSheet: sheet)
        let controller = UIHostingController(rootView: view)
        withSnapshotTesting(record: .missing) {
            assertSnapshot(of: controller, as: .image(on: .iPhone13Pro))
        }
    }
}
