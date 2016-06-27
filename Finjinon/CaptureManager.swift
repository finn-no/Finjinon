//
//  File.swift
//  Finjinon
//
//  Created by Sørensen, Johan on 05.06.15.
//  Copyright (c) 2015 FINN.no AS. All rights reserved.
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
        get {
            return cameraDevice.flashMode
        }
    }
    var hasFlash: Bool {
        return cameraDevice.hasFlash && cameraDevice.isFlashAvailable
    }
    var supportedFlashModes: [AVCaptureFlashMode] {
        var modes: [AVCaptureFlashMode] = []
        for mode in [AVCaptureFlashMode.off, AVCaptureFlashMode.auto, AVCaptureFlashMode.on] {
            if cameraDevice.isFlashModeSupported(mode) {
                modes.append(mode)
            }
        }
        return modes
    }
    let viewfinderMode : CaptureManagerViewfinderMode

    private let session = AVCaptureSession()
    private let captureQueue = DispatchQueue(label: "no.finn.finjinon-captures", attributes: DispatchQueueAttributes.serial)
    private var cameraDevice: AVCaptureDevice!
    private var stillImageOutput: AVCaptureStillImageOutput!
    private var orientation = AVCaptureVideoOrientation.portrait

    override init() {
        session.sessionPreset = AVCaptureSessionPresetPhoto
        var viewfinderMode : CaptureManagerViewfinderMode {
            let screenBounds = UIScreen.main().nativeBounds
            let ratio = screenBounds.height / screenBounds.width
            return ratio <= 1.5 ? .fullScreen : .window
        }
        self.viewfinderMode = viewfinderMode

        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = self.viewfinderMode == .fullScreen ? AVLayerVideoGravityResizeAspectFill : AVLayerVideoGravityResize
        super.init()
        NotificationCenter.default().addObserver(self, selector: #selector(changedOrientationNotification(_:)), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
        changedOrientationNotification(nil)
    }

    deinit {
        NotificationCenter.default().removeObserver(self)
    }

    // MARK: - API

    func authorizationStatus() -> AVAuthorizationStatus {
        return AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
    }

    // Prepares the capture session, possibly asking the user for camera access.
    func prepare(_ completion: (NSError?) -> Void) {
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
            completion(self.accessDeniedError())
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

    func captureImage(_ completion: (Data, NSDictionary) -> Void) { // TODO: throws
        captureQueue.async {
            let connection = self.stillImageOutput.connection(withMediaType: AVMediaTypeVideo)
            connection?.videoOrientation = self.orientation

            self.stillImageOutput.captureStillImageAsynchronously(from: connection, completionHandler: { (sampleBuffer, error) in
                if error == nil {
                    let data = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer)
                    if let metadata = CMCopyDictionaryOfAttachments(nil, sampleBuffer!, CMAttachmentMode(kCMAttachmentMode_ShouldPropagate)) as NSDictionary? {
                        DispatchQueue.main.async {
                            completion(data!, metadata)
                        }
                    } else {
                        print("failed creating metadata")
                    }
                } else {
                    NSLog("Failed capturing still imagE: \(error)")
                    // TODO
                }
            })
        }
    }

    func lockFocusAtPointOfInterest(_ pointInLayer: CGPoint) {
        let pointInCamera = previewLayer.captureDevicePointOfInterest(for: pointInLayer)
        self.lockCurrentCameraDeviceForConfiguration { cameraDevice in
            if cameraDevice.isFocusPointOfInterestSupported {
                cameraDevice.focusPointOfInterest = pointInCamera
                cameraDevice.focusMode = .autoFocus
            }
        }
    }

    func changeFlashMode(_ newMode: AVCaptureFlashMode, completion: () -> Void) {
        lockCurrentCameraDeviceForConfiguration { device in
            device.flashMode = newMode
            DispatchQueue.main.async(execute: completion)
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
        let next = supportedFlashModes[startIndex..<supportedFlashModes.count].first ?? supportedFlashModes.first

        return next
    }

    // Orientation change function required because we've locked the interface in portrait
    // and DeviceOrientation does not map 1:1 with AVCaptureVideoOrientation
    func changedOrientationNotification(_ notification: Notification?) {
        let currentDeviceOrientation = UIDevice.current().orientation
        switch currentDeviceOrientation {
        case .faceDown, .faceUp, .unknown:
            break
        case .landscapeLeft, .landscapeRight, .portrait, .portraitUpsideDown:
            orientation = AVCaptureVideoOrientation(rawValue: currentDeviceOrientation.rawValue)!
        }
    }

    // MARK: - Private methods

    private func accessDeniedError(_ code: Int = FinjinonCameraAccessErrorDeniedCode) -> NSError {
        let info = [NSLocalizedDescriptionKey: NSLocalizedString("Camera access denied, please enable it in the Settings app to continue", comment: "")]
        return NSError(domain: FinjinonCameraAccessErrorDomain, code: code, userInfo: info)
    }

    private func lockCurrentCameraDeviceForConfiguration(_ configurator: (AVCaptureDevice) -> Void) {
        captureQueue.async {
            var error: NSError?
            do {
                try self.cameraDevice.lockForConfiguration()
            } catch let error1 as NSError {
                error = error1
                NSLog("Failed to lock camera device for configuration: \(error)")
            } catch {
                fatalError()
            }

            configurator(self.cameraDevice)

            self.cameraDevice.unlockForConfiguration()
        }
    }

    private func configure(_ completion: (NSError?) -> Void) {
        captureQueue.async {
            self.cameraDevice = self.cameraDeviceWithPosition(.back)
            var error: NSError?

            do {
                let input = try AVCaptureDeviceInput(device: self.cameraDevice)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                } else {
                    // TODO handle?
                    NSLog("failed to add input \(input) to session \(self.session)")
                }
            } catch let error1 as NSError {
                error = error1
                NSLog("failed to create capture device input")
            }

            self.stillImageOutput = AVCaptureStillImageOutput()
            self.stillImageOutput?.outputSettings = [
                AVVideoCodecKey  : AVVideoCodecJPEG,
                AVVideoQualityKey: 0.9
            ]

            if self.session.canAddOutput(self.stillImageOutput) {
                self.session.addOutput(self.stillImageOutput)
            }



            if self.cameraDevice.isFocusModeSupported(.continuousAutoFocus) {
                do {
                    try self.cameraDevice.lockForConfiguration()
                } catch let error2 as NSError {
                    error = error2
                }
                self.cameraDevice.focusMode = .continuousAutoFocus
                if self.cameraDevice.isSmoothAutoFocusSupported {
                    self.cameraDevice.isSmoothAutoFocusEnabled = true
                }
                self.cameraDevice.unlockForConfiguration()
            }

            self.session.startRunning()

            DispatchQueue.main.async {
                completion(error)
            }
        }
    }

    private func cameraDeviceWithPosition(_ position: AVCaptureDevicePosition) -> AVCaptureDevice? {
        let availableCameraDevices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo)
        for device in availableCameraDevices as! [AVCaptureDevice] {
            if device.position == position {
                return device
            }
        }

        return AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
    }
}
