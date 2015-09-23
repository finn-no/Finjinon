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
    case FullScreen
    case Window
}

class CaptureManager: NSObject {
    let previewLayer: AVCaptureVideoPreviewLayer
    var flashMode: AVCaptureFlashMode {
        get {
            return cameraDevice.flashMode
        }
    }
    var hasFlash: Bool {
        return cameraDevice.hasFlash && cameraDevice.flashAvailable
    }
    var supportedFlashModes: [AVCaptureFlashMode] {
        var modes: [AVCaptureFlashMode] = []
        for mode in [AVCaptureFlashMode.Off, AVCaptureFlashMode.Auto, AVCaptureFlashMode.On] {
            if cameraDevice.isFlashModeSupported(mode) {
                modes.append(mode)
            }
        }
        return modes
    }
    let viewfinderMode : CaptureManagerViewfinderMode

    private let session = AVCaptureSession()
    private let captureQueue = dispatch_queue_create("no.finn.finjinon-captures", DISPATCH_QUEUE_SERIAL)
    private var cameraDevice: AVCaptureDevice!
    private var stillImageOutput: AVCaptureStillImageOutput!
    private var orientation = AVCaptureVideoOrientation.Portrait

    override init() {
        session.sessionPreset = AVCaptureSessionPresetPhoto
        var viewfinderMode : CaptureManagerViewfinderMode {
            var screenBounds : CGRect {
                if #available(iOS 8, *) {
                    return UIScreen.mainScreen().nativeBounds
                } else {
                    return UIScreen.mainScreen().bounds
                }
            }
            let ratio = screenBounds.height / screenBounds.width
            return ratio <= 1.5 ? .FullScreen : .Window
        }
        self.viewfinderMode = viewfinderMode

        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = self.viewfinderMode == .FullScreen ? AVLayerVideoGravityResizeAspectFill : AVLayerVideoGravityResize
        super.init()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("changedOrientationNotification:"), name: UIDeviceOrientationDidChangeNotification, object: nil)
        changedOrientationNotification(nil)
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    // MARK: - API

    func authorizationStatus() -> AVAuthorizationStatus {
        return AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)
    }

    // Prepares the capture session, possibly asking the user for camera access.
    func prepare(completion: NSError? -> Void) {
        switch authorizationStatus() {
        case .Authorized:
            configure(completion)
        case .NotDetermined:
            AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo, completionHandler: { granted in
                if granted {
                    self.configure(completion)
                } else {
                    dispatch_async(dispatch_get_main_queue()) {
                        completion(self.accessDeniedError(FinjinonCameraAccessErrorDeniedInitialRequestCode))
                    }
                }
            })
        case .Denied, .Restricted:
            completion(self.accessDeniedError())
        }
    }

    func stop(completion: (() -> Void)?) {
        dispatch_async(captureQueue) {
            if self.session.running {
                self.session.stopRunning()
            }
            completion?()
        }
    }

    func captureImage(completion: (NSData, NSDictionary) -> Void) { // TODO: throws
        dispatch_async(captureQueue) {
            let connection = self.stillImageOutput.connectionWithMediaType(AVMediaTypeVideo)
            connection.videoOrientation = self.orientation

            self.stillImageOutput.captureStillImageAsynchronouslyFromConnection(connection, completionHandler: { (sampleBuffer, error) in
                if error == nil {
                    let data = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer)
                    if let metadata = CMCopyDictionaryOfAttachments(nil, sampleBuffer, CMAttachmentMode(kCMAttachmentMode_ShouldPropagate)) as NSDictionary? {
                        dispatch_async(dispatch_get_main_queue()) {
                            completion(data, metadata)
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

    func lockFocusAtPointOfInterest(pointInLayer: CGPoint) {
        let pointInCamera = previewLayer.captureDevicePointOfInterestForPoint(pointInLayer)
        self.lockCurrentCameraDeviceForConfiguration { cameraDevice in
            if cameraDevice.focusPointOfInterestSupported {
                cameraDevice.focusPointOfInterest = pointInCamera
                cameraDevice.focusMode = .AutoFocus
            }
        }
    }

    func changeFlashMode(newMode: AVCaptureFlashMode, completion: () -> Void) {
        lockCurrentCameraDeviceForConfiguration { device in
            device.flashMode = newMode
            dispatch_async(dispatch_get_main_queue(), completion)
        }
    }

    // Next available flash mode, or nil if flash is unsupported
    func nextAvailableFlashMode() -> AVCaptureFlashMode? {
        if !hasFlash {
            return nil
        }

        // Find the next available mode, or wrap around
        var nextIndex = 0
        if let idx = supportedFlashModes.indexOf(flashMode) {
            nextIndex = idx + 1
        }
        let startIndex = min(nextIndex, supportedFlashModes.count)
        let next = supportedFlashModes[startIndex..<supportedFlashModes.count].first ?? supportedFlashModes.first

        return next
    }

    // Orientation change function required because we've locked the interface in portrait
    // and DeviceOrientation does not map 1:1 with AVCaptureVideoOrientation
    func changedOrientationNotification(notification: NSNotification?) {
        let currentDeviceOrientation = UIDevice.currentDevice().orientation
        switch currentDeviceOrientation {
        case .FaceDown, .FaceUp, .Unknown:
            break
        case .LandscapeLeft, .LandscapeRight, .Portrait, .PortraitUpsideDown:
            orientation = AVCaptureVideoOrientation(rawValue: currentDeviceOrientation.rawValue)!
        }
    }

    // MARK: - Private methods

    private func accessDeniedError(code: Int = FinjinonCameraAccessErrorDeniedCode) -> NSError {
        let info = [NSLocalizedDescriptionKey: NSLocalizedString("Camera access denied, please enable it in the Settings app to continue", comment: "")]
        return NSError(domain: FinjinonCameraAccessErrorDomain, code: code, userInfo: info)
    }

    private func lockCurrentCameraDeviceForConfiguration(configurator: AVCaptureDevice -> Void) {
        dispatch_async(captureQueue) {
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

    private func configure(completion: NSError? -> Void) {
        dispatch_async(captureQueue) {
            self.cameraDevice = self.cameraDeviceWithPosition(.Back)
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



            if self.cameraDevice.isFocusModeSupported(.ContinuousAutoFocus) {
                do {
                    try self.cameraDevice.lockForConfiguration()
                } catch let error2 as NSError {
                    error = error2
                }
                self.cameraDevice.focusMode = .ContinuousAutoFocus
                if self.cameraDevice.smoothAutoFocusSupported {
                    self.cameraDevice.smoothAutoFocusEnabled = true
                }
                self.cameraDevice.unlockForConfiguration()
            }

            self.session.startRunning()

            dispatch_async(dispatch_get_main_queue()) {
                completion(error)
            }
        }
    }

    private func cameraDeviceWithPosition(position: AVCaptureDevicePosition) -> AVCaptureDevice? {
        let availableCameraDevices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
        for device in availableCameraDevices as! [AVCaptureDevice] {
            if device.position == position {
                return device
            }
        }

        return AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
    }
}
