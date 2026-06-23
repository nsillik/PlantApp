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

        let imageToClassify = cropToBestDetection(image) ?? image

        do {
            let result = try await identificationService.classify(image: imageToClassify)
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

    private func bestDetectionBox() -> DetectedBoundingBox? {
        detectionResult.boundingBoxes.max { first, second in
            let scoreFirst = first.normalizedRect.width * first.normalizedRect.height * first.confidence
            let scoreSecond = second.normalizedRect.width * second.normalizedRect.height * second.confidence
            return scoreFirst < scoreSecond
        }
    }

    private func cropToBestDetection(_ image: CGImage) -> CGImage? {
        guard let box = bestDetectionBox() else { return nil }
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let rect = box.normalizedRect
        let crop = CGRect(
            x: rect.origin.x * width,
            y: (1 - rect.origin.y - rect.height) * height,
            width: rect.width * width,
            height: rect.height * height
        )
        return image.cropping(to: crop)
    }

    func confirmSpecies() -> PlantSpecies? {
        resolvedSpecies
    }

    func selectAlternative(_ label: String) {
        if let species = identificationService.resolveModelLabel(label) {
            resolvedSpecies = species
        }
    }

    func reset() {
        cameraState = .running
        detectionResult = DetectionResult(boundingBoxes: [])
        classificationResult = nil
        resolvedSpecies = nil
        errorMessage = nil
    }
}
