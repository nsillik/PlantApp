/// `@preconcurrency import` needed because AVCaptureSession and
/// AVCaptureVideoDataOutputSampleBufferDelegate are not fully Sendable-annotated.
@preconcurrency import AVFoundation
@preconcurrency import CoreVideo
import SwiftUI
import UIKit

/// SwiftUI bridge that owns the live AVFoundation preview, shutter, and cancel controls.
/// Drives `CameraViewModel` for permission state and capture. User-facing overlays
/// (result card, denied state, hint, error) live in `PlantCameraView`, not here.
struct CameraPreviewView: UIViewControllerRepresentable {
    let viewModel: CameraViewModel
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        CameraViewController(viewModel: viewModel, onDismiss: onDismiss)
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}

final class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let viewModel: CameraViewModel
    private let onDismiss: () -> Void
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let sessionQueue = DispatchQueue(label: "com.verdigris.camera.session", qos: .userInitiated)
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var photoCaptureDelegate: PhotoCaptureDelegate?

    private lazy var shutterButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 60, weight: .regular)
        button.setImage(UIImage(systemName: "circle.fill", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowOpacity = 0.3
        button.layer.shadowRadius = 4
        button.addTarget(self, action: #selector(shutterTapped), for: .touchUpInside)
        return button
    }()

    private lazy var cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(String(localized: "Cancel"), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.tintColor = .white
        button.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        return button
    }()

    init(viewModel: CameraViewModel, onDismiss: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkPermission()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }

    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            viewModel.permissionState = .granted
            setupCamera()
        case .notDetermined:
            viewModel.permissionState = .notDetermined
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.viewModel.permissionState = .granted
                        self.setupCamera()
                    } else {
                        self.viewModel.permissionState = .denied
                    }
                }
            }
        case .denied, .restricted:
            viewModel.permissionState = .denied
        @unknown default:
            viewModel.permissionState = .denied
        }
    }

    private func setupCamera() {
        let videoOutput = self.videoOutput
        let photoOutput = self.photoOutput
        let sessionQueue = self.sessionQueue
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let session = AVCaptureSession()
            session.sessionPreset = .photo

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                DispatchQueue.main.async {
                    self.viewModel.cameraState = .idle
                    self.viewModel.errorMessage = String(localized: "Camera hardware unavailable.")
                }
                return
            }

            guard session.canAddInput(input) else { return }
            session.addInput(input)

            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
            guard session.canAddOutput(videoOutput) else { return }
            session.addOutput(videoOutput)

            guard session.canAddOutput(photoOutput) else { return }
            session.addOutput(photoOutput)

            if let connection = videoOutput.connection(with: .video) {
                connection.isEnabled = true
            }

            DispatchQueue.main.async {
                self.captureSession = session
                self.addPreviewLayer(session: session)
                self.addOverlayButtons()
                self.viewModel.cameraState = .running
            }

            session.startRunning()
        }
    }

    private func addPreviewLayer(session: AVCaptureSession) {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer
    }

    private func addOverlayButtons() {
        view.addSubview(shutterButton)
        view.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            cancelButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10)
        ])
    }

    private func stopSession() {
        guard let session = captureSession else { return }
        sessionQueue.async {
            if session.isRunning { session.stopRunning() }
        }
    }

    @objc private func shutterTapped() {
        guard viewModel.cameraState == .running else { return }
        viewModel.cameraState = .capturing

        let settings = AVCapturePhotoSettings()
        let delegate = PhotoCaptureDelegate { [weak self] image in
            guard let self else { return }
            Task { @MainActor in
                self.viewModel.cameraState = .classifying
                await self.viewModel.captureAndClassify(image: image)
            }
        }
        self.photoCaptureDelegate = delegate
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    @objc private func cancelTapped() {
        stopSession()
        onDismiss()
    }

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        Task { @MainActor in
            guard !viewModel.isProcessingFrame else { return }
            guard viewModel.cameraState == .running else { return }
            viewModel.isProcessingFrame = true
            let result = await viewModel.detectPlant(in: pixelBuffer)
            viewModel.updateDetection(result)
        }
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let onComplete: (CGImage) -> Void

    init(onComplete: @escaping (CGImage) -> Void) {
        self.onComplete = onComplete
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let provider = CGDataProvider(data: data as CFData),
              let cgImage = CGImage(jpegDataProviderSource: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { return }
        onComplete(cgImage)
    }
}
