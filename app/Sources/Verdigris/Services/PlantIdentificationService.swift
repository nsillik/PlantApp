import CoreGraphics
import CoreVideo
import Dependencies
import Foundation
import IssueReporting

protocol PlantIdentificationService: Sendable {
    /// Run detection on a camera frame. Returns empty boundingBoxes if no plant found.
    func detectPlant(in pixelBuffer: CVPixelBuffer) async -> DetectionResult
    /// Run classification on a captured image.
    func classify(image: CGImage) async throws -> RawClassificationResult
    /// Join a classifier label to a catalog species via the bundled model-label
    /// map (modelLabel → catalogID) and the catalog service (catalogID → PlantSpecies).
    /// Returns nil if the label has no mapping or the mapped ID is not in the catalog.
    /// Resolution is async because the catalog is sourced via `CatalogService`.
    func resolveModelLabel(_ label: String) async -> PlantSpecies?
}

/// On-device plant identification via CoreML. The detection (`B1`) and
/// classification (`B2`) models are not yet wired in (see Workstream B); their
/// methods `reportIssue` and return a stubbed result. Label resolution is the
/// only production-ready path and resolves against the real catalog so confirmed
/// plants carry the catalog's actual care data — not a fabricated placeholder.
final class CoreMLPlantIdentificationService: PlantIdentificationService, @unchecked Sendable {
    @Dependency(\.catalogService) private var catalogService
    private let labelToCatalogID: [String: UUID]
    private let cacheLock = NSLock()
    private var catalogByIDCache: [UUID: PlantSpecies]?

    init(labelToCatalogID: [String: UUID]? = nil) {
        self.labelToCatalogID = labelToCatalogID ?? Self.loadLabelMapping()
    }

    private static func loadLabelMapping() -> [String: UUID] {
        guard let url = Bundle.main.url(forResource: "model-labels", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let mapping = try? JSONDecoder().decode(ModelLabelsMapping.self, from: data)
        else { return [:] }
        return Dictionary(uniqueKeysWithValues: mapping.labels.compactMap { entry in
            guard let uuid = UUID(uuidString: entry.catalogID) else { return nil }
            return (entry.modelLabel, uuid)
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

    func resolveModelLabel(_ label: String) async -> PlantSpecies? {
        guard let catalogID = labelToCatalogID[label] else { return nil }
        if let cached = catalogByIDLookup() {
            return cached[catalogID]
        }
        let catalog = (try? await catalogService.loadCatalog()) ?? []
        let byID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
        setCache(byID)
        return byID[catalogID]
    }

    private func catalogByIDLookup() -> [UUID: PlantSpecies]? {
        cacheLock.lock(); defer { cacheLock.unlock() }
        return catalogByIDCache
    }

    private func setCache(_ cache: [UUID: PlantSpecies]) {
        cacheLock.lock(); defer { cacheLock.unlock() }
        catalogByIDCache = cache
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

    func resolveModelLabel(_ label: String) async -> PlantSpecies? {
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
