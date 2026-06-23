import SnapshotTesting
import SwiftUI
import Testing

@testable import Verdigris

@MainActor
@Suite("Phase 3 Snapshot Tests")
struct Phase3SnapshotTests {
    let testSpecies = PlantSpecies(
        id: UUID(),
        name: PlantName(commonNamesLocalized: ["en": "Monstera", "es": "Monstera"]),
        scientificName: "Monstera deliciosa",
        wateringInterval: 7
    )

    @Test("CameraResultCard renders with high confidence")
    func resultCardHighConfidence() {
        let result = RawClassificationResult(
            topLabel: "monstera_deliciosa",
            confidence: 0.87,
            alternatives: [
                AlternativeLabel(label: "epipremnum_aureum", confidence: 0.06),
                AlternativeLabel(label: "ficus_lyrata", confidence: 0.03)
            ]
        )
        let view = CameraResultCard(
            species: testSpecies,
            result: result,
            onConfirm: {},
            onSearchCatalog: {},
            onSelectAlternative: { _ in }
        )
        let controller = UIHostingController(rootView: view)
        controller.view.backgroundColor = .systemBackground
        withSnapshotTesting(record: SnapshotRecord.mode) {
            assertSnapshot(of: controller, as: .image(on: .iPhone13Pro))
        }
    }

    @Test("CameraResultCard renders with low confidence")
    func resultCardLowConfidence() {
        let result = RawClassificationResult(
            topLabel: "ficus_lyrata",
            confidence: 0.41,
            alternatives: [
                AlternativeLabel(label: "monstera_deliciosa", confidence: 0.22),
                AlternativeLabel(label: "spathiphyllum_wallisii", confidence: 0.15)
            ]
        )
        let view = CameraResultCard(
            species: PlantSpecies(
                id: UUID(),
                name: PlantName(commonNamesLocalized: ["en": "Ficus"]),
                wateringInterval: 10
            ),
            result: result,
            onConfirm: {},
            onSearchCatalog: {},
            onSelectAlternative: { _ in }
        )
        let controller = UIHostingController(rootView: view)
        controller.view.backgroundColor = .systemBackground
        withSnapshotTesting(record: SnapshotRecord.mode) {
            assertSnapshot(of: controller, as: .image(on: .iPhone13Pro))
        }
    }

    @Test("Identification error overlay renders")
    func errorOverlay() {
        let view = CameraErrorOverlay(
            message: String(localized: "Plant identification is unavailable right now. Search the catalog instead."),
            onSearchCatalog: {},
            onTryAgain: {}
        )
        let controller = UIHostingController(rootView: view)
        controller.view.backgroundColor = .black
        withSnapshotTesting(record: SnapshotRecord.mode) {
            assertSnapshot(of: controller, as: .image(on: .iPhone13Pro))
        }
    }

    @Test("Camera permission denied state renders")
    func permissionDenied() {
        let view = CameraPermissionDeniedView(onOpenSettings: {})
        let controller = UIHostingController(rootView: view)
        controller.view.backgroundColor = .black
        withSnapshotTesting(record: SnapshotRecord.mode) {
            assertSnapshot(of: controller, as: .image(on: .iPhone13Pro))
        }
    }
}
