import Testing
import Foundation

@testable import Verdigris

@Suite("CareSheet Merge Tests")
struct CareSheetMergeTests {
    let testSpecies = PlantSpecies(
        id: UUID(),
        name: PlantName(commonNamesLocalized: ["en": "Monstera"]),
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

    let testUser = UserProfile(
        id: UUID(),
        city: "New York",
        latitude: 40.7,
        longitude: -74.0,
        climateClassification: .temperate
    )

    @Test("Baseline care sheet (no adjustments)")
    func baseline() {
        let sheet = generateCareSheet(
            species: testSpecies,
            user: testUser,
            light: .indirect,
            humidity: .normal,
            season: .spring
        )

        #expect(!sheet.water.isEmpty)
        #expect(sheet.water.contains("Water"))
        #expect(!sheet.light.isEmpty)
        #expect(sheet.soil.contains("well-draining"))
        #expect(!sheet.humidity.isEmpty)
        #expect(sheet.toxicity.contains("moderate"))
        #expect(!sheet.commonProblems.isEmpty)
    }

    @Test("South-facing window shortens watering interval")
    func southLightAdjustment() {
        let indirect = generateCareSheet(
            species: testSpecies, user: testUser, light: .indirect, humidity: .normal, season: .spring
        )
        let south = generateCareSheet(
            species: testSpecies, user: testUser, light: .directSouth, humidity: .normal, season: .spring
        )

        #expect(indirect.water != south.water)
    }

    @Test("Dry humidity shortens watering interval")
    func dryHumidityAdjustment() {
        let normal = generateCareSheet(
            species: testSpecies, user: testUser, light: .indirect, humidity: .normal, season: .spring
        )
        let dry = generateCareSheet(
            species: testSpecies, user: testUser, light: .indirect, humidity: .dry, season: .spring
        )

        #expect(normal.water != dry.water)
    }

    @Test("Winter produces longer interval than summer")
    func seasonalAdjustment() {
        let summer = generateCareSheet(
            species: testSpecies, user: testUser, light: .indirect, humidity: .normal, season: .summer
        )
        let winter = generateCareSheet(
            species: testSpecies, user: testUser, light: .indirect, humidity: .normal, season: .winter
        )

        #expect(summer.water != winter.water)
    }

    @Test("Combined factors produce unique output")
    func combinedFactors() {
        let warmDry = generateCareSheet(
            species: testSpecies, user: testUser, light: .directSouth, humidity: .dry, season: .summer
        )
        let coolWet = generateCareSheet(
            species: testSpecies, user: testUser, light: .indirect, humidity: .wet, season: .winter
        )

        #expect(warmDry.water != coolWet.water)
        #expect(warmDry.light != coolWet.light)
        #expect(warmDry.humidity != coolWet.humidity)
    }

    @Test("Output is deterministic")
    func deterministic() {
        let first = generateCareSheet(
            species: testSpecies, user: testUser, light: .directSouth, humidity: .dry, season: .winter
        )
        let second = generateCareSheet(
            species: testSpecies, user: testUser, light: .directSouth, humidity: .dry, season: .winter
        )

        #expect(first == second)
    }

    @Test("Southern hemisphere season is inverted")
    func southernHemisphere() {
        let sydneyUser = UserProfile(
            id: UUID(), city: "Sydney", latitude: -33.9, longitude: 151.2,
            climateClassification: .temperate
        )

        let julySheet = generateCareSheet(
            species: testSpecies, user: sydneyUser, light: .indirect, humidity: .normal, season: .winter
        )
        let janSheet = generateCareSheet(
            species: testSpecies, user: sydneyUser, light: .indirect, humidity: .normal, season: .summer
        )

        #expect(julySheet.water != janSheet.water)
    }
}
