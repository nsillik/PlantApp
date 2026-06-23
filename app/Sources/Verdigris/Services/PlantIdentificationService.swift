import CoreGraphics
import CoreVideo
import Foundation
import IssueReporting

protocol PlantIdentificationService: Sendable {
    /// Run detection on a camera frame. Returns empty boundingBoxes if no plant found.
    func detectPlant(in pixelBuffer: CVPixelBuffer) async -> DetectionResult
    /// Run classification on a captured image.
    func classify(image: CGImage) async throws -> RawClassificationResult
    /// Map a classifier label string to a catalog species. Returns nil if no match.
    func resolveModelLabel(_ label: String) -> PlantSpecies?
}

final class CoreMLPlantIdentificationService: PlantIdentificationService, @unchecked Sendable {
    private let labels: [String: PlantSpecies]

    init() {
        self.labels = Self.loadLabels()
    }

    private static func loadLabels() -> [String: PlantSpecies] {
        guard let url = Bundle.main.url(forResource: "model-labels", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let mapping = try? JSONDecoder().decode(ModelLabelsMapping.self, from: data)
        else { return [:] }
        return Dictionary(uniqueKeysWithValues: mapping.labels.compactMap { entry in
            guard let uuid = UUID(uuidString: entry.catalogID) else { return nil }
            return (entry.modelLabel, PlantSpecies(
                id: uuid,
                name: PlantName(commonNamesLocalized: ["en": entry.modelLabel]),
                wateringInterval: 7
            ))
        })
    }

    func detectPlant(in pixelBuffer: CVPixelBuffer) async -> DetectionResult {
        reportIssue("CoreMLPlantIdentificationService.detectPlant(in:) not yet implemented — B1 model required")
        return DetectionResult(boundingBoxes: [])
    }

    func classify(image: CGImage) async throws -> RawClassificationResult {
        reportIssue("CoreMLPlantIdentificationService.classify(image:) not yet implemented — B2 model required")
        throw PlantIdentificationError.modelNotAvailable
    }

    func resolveModelLabel(_ label: String) -> PlantSpecies? {
        labels[label]
    }
}

private struct ModelLabelsMapping: Decodable {
    struct LabelEntry: Decodable {
        let modelLabel: String
        let catalogID: String
    }
    let labels: [LabelEntry]
}

final class MockPlantIdentificationService: PlantIdentificationService, @unchecked Sendable {
    var detectionResult: DetectionResult
    var classificationResult: RawClassificationResult
    var resolvedSpecies: PlantSpecies?
    var shouldThrowOnClassify = false

    init(
        detectionResult: DetectionResult = DetectionResult(boundingBoxes: [
            DetectedBoundingBox(normalizedRect: CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6), confidence: 0.92)
        ]),
        classificationResult: RawClassificationResult = RawClassificationResult(
            topLabel: "monstera_deliciosa",
            confidence: 0.87,
            alternatives: [
                AlternativeLabel(label: "epipremnum_aureum", confidence: 0.06),
                AlternativeLabel(label: "ficus_lyrata", confidence: 0.03),
                AlternativeLabel(label: "spathiphyllum_wallisii", confidence: 0.02)
            ]
        ),
        resolvedSpecies: PlantSpecies? = PlantSpecies(
            id: UUID(uuidString: "a1b2c3d4-e5f6-7890-abcd-ef1234567890")!,
            name: PlantName(commonNamesLocalized: ["en": "Monstera"]),
            wateringInterval: 7
        )
    ) {
        self.detectionResult = detectionResult
        self.classificationResult = classificationResult
        self.resolvedSpecies = resolvedSpecies
    }

    func detectPlant(in pixelBuffer: CVPixelBuffer) async -> DetectionResult {
        detectionResult
    }

    func classify(image: CGImage) async throws -> RawClassificationResult {
        if shouldThrowOnClassify {
            throw PlantIdentificationError.classificationFailed("Mock failure")
        }
        return classificationResult
    }

    func resolveModelLabel(_ label: String) -> PlantSpecies? {
        resolvedSpecies
    }
}

enum PlantIdentificationError: Error, LocalizedError {
    case modelNotAvailable
    case classificationFailed(String)
    case unresolvedLabel(String)

    var errorDescription: String? {
        switch self {
        case .modelNotAvailable:
            String(localized: "Plant identification is unavailable.")
        case .classificationFailed(let detail):
            String(localized: "Classification failed: \(detail)")
        case .unresolvedLabel(let label):
            String(localized: "Could not match '\(label)' to any known plant.")
        }
    }
}
