import AVFoundation
import AppKit
import SwiftUI

final class CameraPreviewNSView: NSView {
    private var session: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.cornerRadius = 12
        layer?.masksToBounds = true
        startSession()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        previewLayer?.frame = bounds
    }

    private func startSession() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async { self?.configureCapture() }
                }
            }
        } else if status == .authorized {
            configureCapture()
        }
    }

    private func configureCapture() {
        guard session == nil else { return }
        let capSession = AVCaptureSession()
        capSession.sessionPreset = .medium
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              capSession.canAddInput(input) else {
            return
        }
        capSession.addInput(input)

        let preview = AVCaptureVideoPreviewLayer(session: capSession)
        preview.videoGravity = .resizeAspectFill
        preview.frame = bounds
        if let conn = preview.connection, conn.isVideoMirroringSupported {
            conn.automaticallyAdjustsVideoMirroring = false
            conn.isVideoMirrored = true
        }
        layer?.addSublayer(preview)
        self.previewLayer = preview
        self.session = capSession

        DispatchQueue.global(qos: .userInitiated).async {
            capSession.startRunning()
        }
    }

    func stopSession() {
        let s = session
        session = nil
        DispatchQueue.global(qos: .userInitiated).async {
            s?.stopRunning()
        }
    }

    deinit {
        stopSession()
    }
}

struct CameraMirrorPreview: NSViewRepresentable {
    func makeNSView(context: Context) -> CameraPreviewNSView {
        CameraPreviewNSView(frame: .zero)
    }

    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {}

    static func dismantleNSView(_ nsView: CameraPreviewNSView, coordinator: ()) {
        nsView.stopSession()
    }
}
