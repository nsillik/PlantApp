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

/// State container for the plant-camera flow. Owns permission state, the live
/// detection bodies, the captured classification result, and the species the
/// user has resolved to. All `plantIdentificationService` calls (detect,
/// classify, resolve) are funneled through `@Dependency`, making this fully
/// testable with `MockPlantIdentificationService`.
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

    /// Caches the catalog early so downstream lookups in `PlantCameraView` (e.g.
    /// alternative chips) and CoreML label-resolution have data ready without a
    /// first-class lazy fetch on the shutter tap.
    func loadCatalog() async {
        catalog = (try? await catalogService.loadCatalog()) ?? []
    }

    func updateDetection(_ result: DetectionResult) {
        guard cameraState == .running else { return }
        detectionResult = result
        isProcessingFrame = false
    }

    func detectPlant(in pixelBuffer: CVPixelBuffer) async -> DetectionResult {
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

            if let species = await identificationService.resolveModelLabel(result.topLabel) {
                resolvedSpecies = species
            } else {
                resolvedSpecies = nil
                errorMessage = String(localized: "We couldn't match this result to our catalog.")
            }
        } catch let error as PlantIdentificationError {
            cameraState = .running
            classificationResult = nil
            resolvedSpecies = nil
            switch error {
            case .modelNotAvailable:
                errorMessage = String(localized: "Plant identification is unavailable right now. Search the catalog instead.")
            case .classificationFailed:
                errorMessage = String(localized: "Classification failed. Try again or search the catalog.")
            case .unresolvedLabel:
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
            let areaFirst = first.normalizedRect.width * first.normalizedRect.height
            let areaSecond = second.normalizedRect.width * second.normalizedRect.height

            let centerFirst = CGPoint(
                x: first.normalizedRect.midX - 0.5,
                y: first.normalizedRect.midY - 0.5
            )
            let centerSecond = CGPoint(
                x: second.normalizedRect.midX - 0.5,
                y: second.normalizedRect.midY - 0.5
            )
            let distFirst = sqrt(centerFirst.x * centerFirst.x + centerFirst.y * centerFirst.y)
            let distSecond = sqrt(centerSecond.x * centerSecond.x + centerSecond.y * centerSecond.y)
            let centralityFirst = 1 - distFirst / 0.7071
            let centralitySecond = 1 - distSecond / 0.7071

            let scoreFirst = areaFirst * first.confidence * max(centralityFirst, 0.1)
            let scoreSecond = areaSecond * second.confidence * max(centralitySecond, 0.1)
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

    /// Returns the current resolved species (top-match or whichever alternative
    /// the user picked via `selectAlternative`). Returns nil until a successful
    /// classify+resolve has run.
    func confirmSpecies() -> PlantSpecies? {
        resolvedSpecies
    }

    /// Switches `resolvedSpecies` to the species matching `label` from the
    /// classifier's alternative list. Async because label→species resolution
    /// resolves against the (async) catalog service.
    func selectAlternative(_ label: String) async {
        if let species = await identificationService.resolveModelLabel(label) {
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
