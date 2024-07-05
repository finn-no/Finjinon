//
//  Copyright (c) 2017 FINN.no AS. All rights reserved.
//

import UIKit
import AVFoundation

enum CaptureManagerViewfinderMode {
    case fullScreen
    case window
}

protocol CaptureManagerDelegate: AnyObject {
    func captureManager(_ manager: CaptureManager, didCaptureImageData data: Data?, withMetadata metadata: NSDictionary?)
    func captureManager(_ manager: CaptureManager, didDetectLightingCondition: LightingCondition)
    func captureManager(_ manager: CaptureManager, didFailWithError error: NSError)
}

extension CaptureManagerDelegate {
    func captureManager(_ manager: CaptureManager, didFailWithError error: NSError) {}
}

class CaptureManager: NSObject {
    weak var delegate: CaptureManagerDelegate?

    let previewLayer: AVCaptureVideoPreviewLayer
    let viewfinderMode: CaptureManagerViewfinderMode

    var flashMode: AVCaptureDevice.FlashMode = .auto

    var hasFlash: Bool {
        return cameraDevice?.hasFlash ?? false && cameraDevice?.isFlashAvailable ?? false
    }

    var supportedFlashModes: [AVCaptureDevice.FlashMode] {
        var modes: [AVCaptureDevice.FlashMode] = []
        for mode in [AVCaptureDevice.FlashMode.off, AVCaptureDevice.FlashMode.auto, AVCaptureDevice.FlashMode.on] {
            #if !targetEnvironment(simulator)
            if cameraOutput.supportedFlashModes.contains(mode) {
                modes.append(mode)
            }
            #endif
        }
        return modes
    }

    private let session = AVCaptureSession()
    private let captureQueue = DispatchQueue(label: "no.finn.finjinon-captures", attributes: [])
    private var cameraDevice: AVCaptureDevice?
    private var cameraOutput: AVCapturePhotoOutput
    private var cameraSettings: AVCapturePhotoSettings?
    private var orientation = AVCaptureVideoOrientation.portrait
    private var lastVideoCaptureTime = CMTime()
    private let lowLightService = LowLightService()

    private var didCaptureImageCompletion: ((Data, NSDictionary) -> Void)?

    /// Array of vision requests

    override init() {
        session.sessionPreset = AVCaptureSession.Preset.photo
        var viewfinderMode: CaptureManagerViewfinderMode {
            let screenBounds = UIScreen.main.nativeBounds
            let ratio = screenBounds.height / screenBounds.width
            return ratio <= 1.5 ? .fullScreen : .window
        }
        self.viewfinderMode = viewfinderMode

        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = self.viewfinderMode == .fullScreen ? AVLayerVideoGravity.resizeAspectFill : AVLayerVideoGravity.resize
        cameraOutput = AVCapturePhotoOutput()
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(changedOrientationNotification(_:)), name: UIDevice.orientationDidChangeNotification, object: nil)
        changedOrientationNotification(nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - API

    func authorizationStatus() -> AVAuthorizationStatus {
        return AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
    }

    // Prepares the capture session, possibly asking the user for camera access.
    func prepare(_ completion: @escaping (NSError?) -> Void) {
        switch authorizationStatus() {
        case .authorized:
            configure(completion)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { granted in
                if granted {
                    self.configure(completion)
                } else {
                    DispatchQueue.main.async {
                        completion(self.accessDeniedError(FinjinonCameraAccessErrorDeniedInitialRequestCode))
                    }
                }
            })
        case .denied, .restricted:
            completion(accessDeniedError())
        @unknown default:
            return
        }
    }

    func stop(_ completion: (() -> Void)?) {
        captureQueue.async { [weak self] in
            guard let self = self else { return }

            if self.session.isRunning {
                self.session.stopRunning()
            }
            completion?()
        }
    }

    @available(*, deprecated, message: "Conform to the CaptureManagerDelegate and handle it in captureManager(_ manager: CaptureManager, didCaptureImage data: Data?, withMetadata metadata: NSDictionary?)")
    func captureImage(_ completion: @escaping (Data, NSDictionary) -> Void) {
        didCaptureImageCompletion = completion
        captureImage()
    }

    func captureImage() {
        captureQueue.async { [weak self] in
            guard let self = self else { return }
            guard let connection = self.cameraOutput.connection(with: .video) else { return }

            connection.videoOrientation = self.orientation
            self.cameraSettings = self.createCapturePhotoSettingsObject()

            guard let cameraSettings = self.cameraSettings else { return }
            #if !targetEnvironment(simulator)
            if !self.cameraOutput.supportedFlashModes.contains(cameraSettings.flashMode) {
                cameraSettings.flashMode = .off
            }
            #endif
            self.cameraOutput.capturePhoto(with: cameraSettings, delegate: self)
        }
    }

    func lockFocusAtPointOfInterest(_ pointInLayer: CGPoint) {
        let pointInCamera = previewLayer.captureDevicePointConverted(fromLayerPoint: pointInLayer)
        lockCurrentCameraDeviceForConfiguration { cameraDevice in
            if let cameraDevice = self.cameraDevice, cameraDevice.isFocusPointOfInterestSupported {
                cameraDevice.focusPointOfInterest = pointInCamera
                cameraDevice.focusMode = .autoFocus
            }
        }
    }

    func changeFlashMode(_ newMode: AVCaptureDevice.FlashMode, completion: @escaping () -> Void) {
        flashMode = newMode
        cameraSettings = createCapturePhotoSettingsObject()
        DispatchQueue.main.async(execute: completion)
    }

    // Next available flash mode, or nil if flash is unsupported
    func nextAvailableFlashMode() -> AVCaptureDevice.FlashMode? {
        if !hasFlash {
            return nil
        }

        // Find the next available mode, or wrap around
        var nextIndex = 0
        if let idx = supportedFlashModes.firstIndex(of: flashMode) {
            nextIndex = idx + 1
        }

        let startIndex = min(nextIndex, supportedFlashModes.count)
        let next = supportedFlashModes[startIndex ..< supportedFlashModes.count].first ?? supportedFlashModes.first
        if let nextFlashMode = next { flashMode = nextFlashMode }

        return next
    }

    // Orientation change function required because we've locked the interface in portrait
    // and DeviceOrientation does not map 1:1 with AVCaptureVideoOrientation
    @objc func changedOrientationNotification(_: Notification?) {
        let currentDeviceOrientation = UIDevice.current.orientation
        switch currentDeviceOrientation {
        case .faceDown, .faceUp, .unknown:
            break
        case .landscapeLeft, .landscapeRight, .portrait, .portraitUpsideDown:
            orientation = AVCaptureVideoOrientation(rawValue: currentDeviceOrientation.rawValue) ?? .portrait
        @unknown default:
            return
        }
    }
}

// MARK: - Private methods

private extension CaptureManager {
    func createCapturePhotoSettingsObject() -> AVCapturePhotoSettings {
        var newCameraSettings: AVCapturePhotoSettings

        if let currentCameraSettings = cameraSettings {
            newCameraSettings = AVCapturePhotoSettings(from: currentCameraSettings)
            newCameraSettings.flashMode = flashMode
        } else {
            newCameraSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecJPEG, AVVideoCompressionPropertiesKey: [AVVideoQualityKey: 0.9]])
            newCameraSettings.flashMode = flashMode
        }

        return newCameraSettings
    }

    func accessDeniedError(_ code: Int = FinjinonCameraAccessErrorDeniedCode) -> NSError {
        let info = [NSLocalizedDescriptionKey: Finjinon.configuration.texts.cameraAccessDenied]
        return NSError(domain: FinjinonCameraAccessErrorDomain, code: code, userInfo: info)
    }

    func lockCurrentCameraDeviceForConfiguration(_ configurator: @escaping (AVCaptureDevice?) -> Void) {
        captureQueue.async { [weak self] in
            guard let self = self else { return }

            do {
                try self.cameraDevice?.lockForConfiguration()
            } catch let error as NSError {
                self.delegate?.captureManager(self, didFailWithError: error)
            } catch {
                fatalError()
            }

            configurator(self.cameraDevice)

            self.cameraDevice?.unlockForConfiguration()
        }
    }

    func configure(_ completion: @escaping (NSError?) -> Void) {
        captureQueue.async { [weak self] in
            guard let self = self else { return }

            self.cameraDevice = self.cameraDeviceWithPosition(.back)
            var error: NSError?

            do {
                let input = try AVCaptureDeviceInput(device: self.cameraDevice!)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                } else {
                    NSLog("Failed to add input \(input) to session \(self.session)")
                }
            } catch let error1 as NSError {
                error = error1
                self.delegate?.captureManager(self, didFailWithError: error1)
            }

            if self.session.canAddOutput(self.cameraOutput) {
                self.session.addOutput(self.cameraOutput)
            }

            let videoOutput = self.makeVideoDataOutput()
            if self.session.canAddOutput(videoOutput) {
                self.session.addOutput(videoOutput)
            }

            if let cameraDevice = self.cameraDevice {
                if cameraDevice.isFocusModeSupported(.continuousAutoFocus) {
                    do {
                        try cameraDevice.lockForConfiguration()
                    } catch let error1 as NSError {
                        error = error1
                        self.delegate?.captureManager(self, didFailWithError: error1)
                    }
                    cameraDevice.focusMode = .continuousAutoFocus
                    if cameraDevice.isSmoothAutoFocusSupported {
                        cameraDevice.isSmoothAutoFocusEnabled = true
                    }
                    cameraDevice.unlockForConfiguration()
                }
            }

            self.session.startRunning()

            DispatchQueue.main.async {
                completion(error)
            }
        }
    }

    func cameraDeviceWithPosition(_ position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType]

        if #available(iOS 11.2, *) {
            deviceTypes = [.builtInTrueDepthCamera, .builtInDualCamera, .builtInWideAngleCamera]
        } else {
            deviceTypes = [.builtInWideAngleCamera]
        }

        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: .video, position: .unspecified)
        let availableCameraDevices = discoverySession.devices

        guard availableCameraDevices.isEmpty == false else {
            print("Error no camera devices found")
            return nil
        }

        for device in availableCameraDevices {
            if device.position == position {
                return device
            }
        }

        return AVCaptureDevice.default(for: AVMediaType.video)
    }

    func makeVideoDataOutput() -> AVCaptureVideoDataOutput {
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "no.finn.finjinon-sample-buffer"))
        return output
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CaptureManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {

        // We either call the delegate or the completion block not both.
        if didCaptureImageCompletion != nil && delegate != nil {
            didCaptureImageCompletion = nil
        }

        guard error == nil else {
            if let error = error { delegate?.captureManager(self, didFailWithError: error as NSError) }
            return
        }

        if let sampleBuffer = photoSampleBuffer, let data = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: sampleBuffer, previewPhotoSampleBuffer: nil) {
            if let metadata = CMCopyDictionaryOfAttachments(allocator: nil, target: sampleBuffer, attachmentMode: CMAttachmentMode(kCMAttachmentMode_ShouldPropagate)) as NSDictionary? {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if let completion = self.didCaptureImageCompletion {
                        completion(data, metadata)
                    } else {
                        self.delegate?.captureManager(self, didCaptureImageData: data, withMetadata: metadata)
                    }
                }
            } else {
                if let error = error { delegate?.captureManager(self, didFailWithError: error as NSError) }
            }
        } else {
            if let error = error { delegate?.captureManager(self, didFailWithError: error as NSError) }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CaptureManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let fps: Int32 = 1 // Create pixel buffer and call the delegate 1 time per second

        guard (time - lastVideoCaptureTime) >= CMTime.init(value: 1, timescale: fps) else {
            return
        }

        lastVideoCaptureTime = time

        if let lightningCondition = lowLightService.getLightningCondition(from: sampleBuffer) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.captureManager(self, didDetectLightingCondition: lightningCondition)
            }
        }
    }
}
