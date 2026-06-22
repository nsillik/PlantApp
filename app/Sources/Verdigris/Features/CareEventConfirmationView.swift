import PhotosUI
import SwiftUI

struct CareEventConfirmationView: View {
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showCameraCapture = false
    private let cameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)

    let viewModel: PlantDetailViewModel
    let pendingEvent: PendingCareEvent

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: icon(for: pendingEvent.eventType))
                            .font(.title)
                            .foregroundStyle(color(for: pendingEvent.eventType))
                        Text(label(for: pendingEvent.eventType))
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section(String(localized: "Photo")) {
                    if let data = viewModel.pendingEventPhotoData,
                       let uiImage = UIImage(data: data) {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Button {
                                viewModel.pendingEventPhotoData = nil
                                selectedPhotoItem = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white, Color.black.opacity(0.5))
                                    .font(.title2)
                            }
                            .padding(4)
                        }
                    } else {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label(String(localized: "Choose Photo"), systemImage: "photo.on.rectangle")
                        }
                        .onChange(of: selectedPhotoItem) { _, item in
                            guard let item else { return }
                            Task { await viewModel.loadPhoto(from: item) }
                        }

                        if cameraAvailable {
                            Button {
                                showCameraCapture = true
                            } label: {
                                Label(String(localized: "Take Photo"), systemImage: "camera")
                            }
                        }
                    }
                }

                Section(String(localized: "Notes")) {
                    TextEditor(text: Binding(
                        get: { viewModel.pendingEventNotes },
                        set: { viewModel.pendingEventNotes = $0 }
                    ))
                    .frame(minHeight: 100)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        viewModel.cancelCareEvent()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Confirm")) {
                        Task { await viewModel.confirmCareEvent() }
                    }
                }
            }
        }
        .sheet(isPresented: $showCameraCapture) {
            CameraCaptureView { image in
                viewModel.handleCameraCapture(image)
                showCameraCapture = false
            }
        }
    }

    private func icon(for type: CareEventType) -> String {
        switch type {
        case .watered: "drop.fill"
        case .fertilized: "leaf.arrow.circlepath"
        case .pruned: "scissors"
        case .repotted: "tray.full"
        }
    }

    private func color(for type: CareEventType) -> Color {
        switch type {
        case .watered: .blue
        case .fertilized: .green
        case .pruned: .orange
        case .repotted: .brown
        }
    }

    private func label(for type: CareEventType) -> String {
        switch type {
        case .watered: String(localized: "Watered")
        case .fertilized: String(localized: "Fertilized")
        case .pruned: String(localized: "Pruned")
        case .repotted: String(localized: "Repotted")
        }
    }
}
