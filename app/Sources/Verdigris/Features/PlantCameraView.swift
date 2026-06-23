import AVFoundation
import SwiftUI
import UIKit

struct PlantCameraView: UIViewControllerRepresentable {
    let viewModel: CameraViewModel
    let onDismiss: () -> Void
    let onSpeciesConfirmed: (PlantSpecies) -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        CameraViewController(viewModel: viewModel, onDismiss: onDismiss, onSpeciesConfirmed: onSpeciesConfirmed)
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}

final class CameraViewController: UIViewController {
    private let viewModel: CameraViewModel
    private let onDismiss: () -> Void
    private let onSpeciesConfirmed: (PlantSpecies) -> Void
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

    init(viewModel: CameraViewModel, onDismiss: @escaping () -> Void, onSpeciesConfirmed: @escaping (PlantSpecies) -> Void) {
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        self.onSpeciesConfirmed = onSpeciesConfirmed
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
                    if granted {
                        self?.viewModel.permissionState = .granted
                        self?.setupCamera()
                    } else {
                        self?.viewModel.permissionState = .denied
                        self?.showPermissionDenied()
                    }
                }
            }
        case .denied, .restricted:
            viewModel.permissionState = .denied
            showPermissionDenied()
        @unknown default:
            viewModel.permissionState = .denied
            showPermissionDenied()
        }
    }

    private func showPermissionDenied() {
        viewModel.cameraState = .idle
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = String(localized: "Camera access is needed to identify plants.")
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        view.addSubview(label)

        let settingsButton = UIButton(type: .system)
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.setTitle(String(localized: "Open Settings"), for: .normal)
        settingsButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        settingsButton.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        view.addSubview(settingsButton)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40),
            settingsButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            settingsButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 20),
        ])
    }

    private func setupCamera() {
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

            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            self.videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            guard session.canAddOutput(self.videoOutput) else { return }
            session.addOutput(self.videoOutput)

            guard session.canAddOutput(self.photoOutput) else { return }
            session.addOutput(self.photoOutput)

            if let connection = self.videoOutput.connection(with: .video) {
                connection.isEnabled = true
            }

            self.captureSession = session

            DispatchQueue.main.async {
                self.addPreviewLayer(session: session)
                self.addOverlayButtons()
                session.startRunning()
                self.viewModel.cameraState = .running
            }
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
            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
        ])
    }

    private func stopSession() {
        captureSession?.stopRunning()
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

    @objc private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
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
