import SwiftUI
import UIKit

/// SwiftUI host for the AI-assisted plant identification flow. Stacks the live
/// preview (`CameraPreviewView`) with user-facing overlays: detected bounding
/// boxes, "point at a plant" hint, classifying spinner, result card, and the
/// permission-denied prompt. Camera plumbing (AVFoundation session, shutter) is
/// owned by `CameraPreviewView`; permission state is surfaced via `CameraViewModel`.
struct PlantCameraView: View {
    @State private var viewModel: CameraViewModel
    @State private var showCatalogSearch = false
    let onSpeciesConfirmed: (PlantSpecies) -> Void
    let onDismiss: () -> Void

    init(viewModel: CameraViewModel = CameraViewModel(), onSpeciesConfirmed: @escaping (PlantSpecies) -> Void, onDismiss: @escaping () -> Void) {
        self._viewModel = State(initialValue: viewModel)
        self.onSpeciesConfirmed = onSpeciesConfirmed
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            CameraPreviewView(viewModel: viewModel, onDismiss: onDismiss)
                .ignoresSafeArea()

            if viewModel.permissionState == .denied {
                CameraPermissionDeniedView(onOpenSettings: openSettings)
            } else if viewModel.permissionState == .granted {
                overlayContent
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .task {
            await viewModel.loadCatalog()
        }
        .sheet(isPresented: $showCatalogSearch) {
            catalogSearchSheet
        }
    }

    @ViewBuilder
    private var overlayContent: some View {
        detectionOverlay

        if viewModel.cameraState == .classifying {
            classifyingOverlay
        } else if let error = viewModel.errorMessage {
            errorOverlay(message: error)
        } else if let result = viewModel.classificationResult, let species = viewModel.resolvedSpecies {
            resultCardOverlay(result: result, species: species)
        } else if viewModel.cameraState == .running || viewModel.cameraState == .idle {
            hintOverlay
        }
    }

    private var classifyingOverlay: some View {
        VStack {
            Spacer()
            ProgressView(String(localized: "Identifying plant…"))
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Spacer().frame(height: 120)
        }
    }

    private var hintOverlay: some View {
        VStack {
            Spacer()
            Text(String(localized: "Point your camera at a plant"))
                .font(.headline)
                .foregroundStyle(.white)
                .padding()
                .background(.black.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.bottom, 120)
        }
    }

    private var detectionOverlay: some View {
        GeometryReader { geometry in
            ForEach(viewModel.detectionResult.boundingBoxes) { box in
                let rect = normalizedToView(box.normalizedRect, in: geometry.size)
                Rectangle()
                    .stroke(.green, lineWidth: 2)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            }
        }
        .allowsHitTesting(false)
    }

    private func errorOverlay(message: String) -> some View {
        VStack {
            Spacer()
            CameraErrorOverlay(
                message: message,
                onSearchCatalog: { showCatalogSearch = true },
                onTryAgain: { viewModel.reset() }
            )
            Spacer().frame(height: 120)
        }
    }

    private func resultCardOverlay(result: RawClassificationResult, species: PlantSpecies) -> some View {
        VStack {
            Spacer()
            CameraResultCard(
                species: species,
                result: result,
                onConfirm: {
                    if let confirmed = viewModel.confirmSpecies() {
                        onSpeciesConfirmed(confirmed)
                    }
                },
                onSearchCatalog: {
                    showCatalogSearch = true
                },
                onSelectAlternative: { label in
                    Task { await viewModel.selectAlternative(label) }
                }
            )
            .padding(.horizontal)
            .padding(.bottom, 80)
        }
    }

    private var catalogSearchSheet: some View {
        NavigationStack {
            CatalogBrowseView { species, _ in
                onSpeciesConfirmed(species)
                showCatalogSearch = false
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "Back to Camera")) {
                        showCatalogSearch = false
                    }
                }
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private func normalizedToView(_ rect: CGRect, in size: CGSize) -> CGRect {
    CGRect(
        x: rect.origin.x * size.width,
        y: (1 - rect.origin.y - rect.height) * size.height,
        width: rect.width * size.width,
        height: rect.height * size.height
    )
}

struct CameraErrorOverlay: View {
    let message: String
    let onSearchCatalog: () -> Void
    let onTryAgain: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
            Button(String(localized: "Search Catalog")) {
                onSearchCatalog()
            }
            .buttonStyle(.borderedProminent)
            Button(String(localized: "Try Again")) {
                onTryAgain()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
    }
}

/// Permission-denied overlay shown when the user has declined camera access.
/// Renders the explanatory message plus a single button that deep-links to the
/// app's privacy settings via `UIApplication.openSettingsURLString`.
struct CameraPermissionDeniedView: View {
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text(String(localized: "Camera access is needed to identify plants."))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Button(String(localized: "Open Settings")) {
                onOpenSettings()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct CameraResultCard: View {
    let species: PlantSpecies
    let result: RawClassificationResult
    let onConfirm: () -> Void
    let onSearchCatalog: () -> Void
    let onSelectAlternative: (String) -> Void

    private var isLowConfidence: Bool {
        result.confidence < 0.6
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(species.name.localizedName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .lineLimit(2)

            confidenceBar

            Text(String(localized: "Is this right?"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if isLowConfidence {
                Text(String(localized: "We're not completely sure — tap Search to pick the right species"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button(String(localized: "Confirm")) {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(String(localized: "Search Catalog")) {
                    onSearchCatalog()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            if !result.alternatives.isEmpty {
                alternativeChips
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 8)
    }

    private var confidenceBar: some View {
        VStack(spacing: 4) {
            HStack {
                Text(String(localized: "Confidence"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(result.confidence * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(isLowConfidence ? .orange : .green)
            }
            ProgressView(value: result.confidence)
                .tint(isLowConfidence ? .orange : .green)
        }
    }

    private var alternativeChips: some View {
        VStack(spacing: 4) {
            Text(String(localized: "Also match"))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(result.alternatives, id: \.label) { alt in
                    Button {
                        onSelectAlternative(alt.label)
                    } label: {
                        Text(alt.label.replacingOccurrences(of: "_", with: " "))
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.secondary.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
