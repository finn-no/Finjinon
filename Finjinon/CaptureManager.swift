//
//  Copyright (c) 2017 FINN.no AS. All rights reserved.
//

import UIKit
import AVFoundation

enum CaptureManagerViewfinderMode {
    case fullScreen
    case window
}

class CaptureManager: NSObject {
    let previewLayer: AVCaptureVideoPreviewLayer
    var flashMode: AVCaptureFlashMode {
        return cameraDevice?.flashMode ?? .off
    }

    var hasFlash: Bool {
        return cameraDevice?.hasFlash ?? false && cameraDevice?.isFlashAvailable ?? false
    }

    var supportedFlashModes: [AVCaptureFlashMode] {
        var modes: [AVCaptureFlashMode] = []
        for mode in [AVCaptureFlashMode.off, AVCaptureFlashMode.auto, AVCaptureFlashMode.on] {
            if let cameraDevice = cameraDevice, cameraDevice.isFlashModeSupported(mode) {
                modes.append(mode)
            }
        }
        return modes
    }

    let viewfinderMode: CaptureManagerViewfinderMode

    fileprivate let session = AVCaptureSession()
    fileprivate let captureQueue = DispatchQueue(label: "no.finn.finjinon-captures", attributes: [])
    fileprivate var cameraDevice: AVCaptureDevice?
    fileprivate var stillImageOutput: AVCaptureStillImageOutput?
    fileprivate var orientation = AVCaptureVideoOrientation.portrait

    override init() {
        session.sessionPreset = AVCaptureSessionPresetPhoto
        var viewfinderMode: CaptureManagerViewfinderMode {
            let screenBounds = UIScreen.main.nativeBounds
            let ratio = screenBounds.height / screenBounds.width
            return ratio <= 1.5 ? .fullScreen : .window
        }
        self.viewfinderMode = viewfinderMode

        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = self.viewfinderMode == .fullScreen ? AVLayerVideoGravityResizeAspectFill : AVLayerVideoGravityResize
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(changedOrientationNotification(_:)), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
        changedOrientationNotification(nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - API

    func authorizationStatus() -> AVAuthorizationStatus {
        return AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
    }

    // Prepares the capture session, possibly asking the user for camera access.
    func prepare(_ completion: @escaping (NSError?) -> Void) {
        switch authorizationStatus() {
        case .authorized:
            configure(completion)
        case .notDetermined:
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { granted in
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
        }
    }

    func stop(_ completion: (() -> Void)?) {
        captureQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
            completion?()
        }
    }

    func captureImage(_ completion: @escaping (Data, NSDictionary) -> Void) { // TODO: throws
        captureQueue.async {
            guard let connection = self.stillImageOutput?.connection(withMediaType: AVMediaTypeVideo) else {
                return
            }
            connection.videoOrientation = self.orientation

            self.stillImageOutput?.captureStillImageAsynchronously(from: connection, completionHandler: { sampleBuffer, error in
                if error == nil {
                    if let sampleBuffer = sampleBuffer, let data = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer) {
                        if let metadata = CMCopyDictionaryOfAttachments(nil, sampleBuffer, CMAttachmentMode(kCMAttachmentMode_ShouldPropagate)) as NSDictionary? {
                            DispatchQueue.main.async {
                                completion(data, metadata)
                            }
                        } else {
                            print("failed creating metadata")
                        }
                    }
                } else {
                    NSLog("Failed capturing still imagE: \(String(describing: error))")
                    // TODO:
                }
            })
        }
    }

    func lockFocusAtPointOfInterest(_ pointInLayer: CGPoint) {
        let pointInCamera = previewLayer.captureDevicePointOfInterest(for: pointInLayer)
        lockCurrentCameraDeviceForConfiguration { cameraDevice in
            if let cameraDevice = self.cameraDevice, cameraDevice.isFocusPointOfInterestSupported {
                cameraDevice.focusPointOfInterest = pointInCamera
                cameraDevice.focusMode = .autoFocus
            }
        }
    }

    func changeFlashMode(_ newMode: AVCaptureFlashMode, completion: @escaping () -> Void) {
        lockCurrentCameraDeviceForConfiguration { device in
            if let device = device {
                device.flashMode = newMode
                DispatchQueue.main.async(execute: completion)
            }
        }
    }

    // Next available flash mode, or nil if flash is unsupported
    func nextAvailableFlashMode() -> AVCaptureFlashMode? {
        if !hasFlash {
            return nil
        }

        // Find the next available mode, or wrap around
        var nextIndex = 0
        if let idx = supportedFlashModes.index(of: flashMode) {
            nextIndex = idx + 1
        }
        let startIndex = min(nextIndex, supportedFlashModes.count)
        let next = supportedFlashModes[startIndex ..< supportedFlashModes.count].first ?? supportedFlashModes.first

        return next
    }

    // Orientation change function required because we've locked the interface in portrait
    // and DeviceOrientation does not map 1:1 with AVCaptureVideoOrientation
    func changedOrientationNotification(_: Notification?) {
        let currentDeviceOrientation = UIDevice.current.orientation
        switch currentDeviceOrientation {
        case .faceDown, .faceUp, .unknown:
            break
        case .landscapeLeft, .landscapeRight, .portrait, .portraitUpsideDown:
            orientation = AVCaptureVideoOrientation(rawValue: currentDeviceOrientation.rawValue) ?? .portrait
        }
    }

    // MARK: - Private methods

    fileprivate func accessDeniedError(_ code: Int = FinjinonCameraAccessErrorDeniedCode) -> NSError {
        let info = [NSLocalizedDescriptionKey: NSLocalizedString("Camera access denied, please enable it in the Settings app to continue", comment: "")]
        return NSError(domain: FinjinonCameraAccessErrorDomain, code: code, userInfo: info)
    }

    fileprivate func lockCurrentCameraDeviceForConfiguration(_ configurator: @escaping (AVCaptureDevice?) -> Void) {
        captureQueue.async {
            var error: NSError?
            do {
                try self.cameraDevice?.lockForConfiguration()
            } catch let error1 as NSError {
                error = error1
                NSLog("Failed to lock camera device for configuration: \(String(describing: error))")
            } catch {
                fatalError()
            }

            configurator(self.cameraDevice)

            self.cameraDevice?.unlockForConfiguration()
        }
    }

    fileprivate func configure(_ completion: @escaping (NSError?) -> Void) {
        captureQueue.async {
            self.cameraDevice = self.cameraDeviceWithPosition(.back)
            var error: NSError?

            do {
                let input = try AVCaptureDeviceInput(device: self.cameraDevice)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                } else {
                    // TODO: handle?
                    NSLog("failed to add input \(input) to session \(self.session)")
                }
            } catch let error1 as NSError {
                error = error1
                NSLog("failed to create capture device input")
            }

            self.stillImageOutput = AVCaptureStillImageOutput()
            self.stillImageOutput?.outputSettings = [
                AVVideoCodecKey: AVVideoCodecJPEG,
                AVVideoQualityKey: 0.9,
            ]

            if self.session.canAddOutput(self.stillImageOutput) {
                self.session.addOutput(self.stillImageOutput)
            }

            if let cameraDevice = self.cameraDevice {
                if cameraDevice.isFocusModeSupported(.continuousAutoFocus) {
                    do {
                        try cameraDevice.lockForConfiguration()
                    } catch let error2 as NSError {
                        error = error2
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

    fileprivate func cameraDeviceWithPosition(_ position: AVCaptureDevicePosition) -> AVCaptureDevice? {
        if let availableCameraDevices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as? [AVCaptureDevice] {
            for device in availableCameraDevices {
                if device.position == position {
                    return device
                }
            }
        }

        return AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
    }
}
