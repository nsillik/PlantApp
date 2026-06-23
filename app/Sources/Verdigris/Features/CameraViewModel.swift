import CoreGraphics
import CoreVideo
import Dependencies
import Foundation

enum CameraPermissionState: Sendable {
    case notDetermined
    case granted
    case denied
}

enum CameraSessionState: Sendable {
    case idle
    case running
    case capturing
    case classifying
}

@MainActor
@Observable
final class CameraViewModel {
    var cameraState: CameraSessionState = .idle
    var permissionState: CameraPermissionState = .notDetermined
    var detectionResult: DetectionResult = DetectionResult(boundingBoxes: [])
    var classificationResult: RawClassificationResult?
    var resolvedSpecies: PlantSpecies?
    var errorMessage: String?
    var isProcessingFrame = false

    @ObservationIgnored
    @Dependency(\.plantIdentificationService) private var identificationService
    @ObservationIgnored
    @Dependency(\.catalogService) private var catalogService

    private var catalog: [PlantSpecies] = []

    func loadCatalog() async {
        catalog = (try? await catalogService.loadCatalog()) ?? []
    }

    func updateDetection(_ result: DetectionResult) {
        guard cameraState == .running else { return }
        detectionResult = result
        isProcessingFrame = false
    }

    nonisolated func detectPlant(in pixelBuffer: CVPixelBuffer) async -> DetectionResult {
        await identificationService.detectPlant(in: pixelBuffer)
    }

    func captureAndClassify(image: CGImage) async {
        cameraState = .classifying
        errorMessage = nil

        do {
            let result = try await identificationService.classify(image: image)
            classificationResult = result
            cameraState = .running

            if let species = identificationService.resolveModelLabel(result.topLabel) {
                resolvedSpecies = species
            } else {
                resolvedSpecies = nil
                errorMessage = String(localized: "We couldn't match this result to our catalog.")
            }
        } catch {
            cameraState = .running
            errorMessage = String(localized: "Classification failed. Try again or search the catalog.")
            classificationResult = nil
            resolvedSpecies = nil
        }
    }

    func confirmSpecies() -> PlantSpecies? {
        resolvedSpecies
    }

    func reset() {
        cameraState = .running
        detectionResult = DetectionResult(boundingBoxes: [])
        classificationResult = nil
        resolvedSpecies = nil
        errorMessage = nil
    }
}
