//
//  File.swift
//  Finjinon
//
//  Created by Sørensen, Johan on 05.06.15.
//  Copyright (c) 2015 FINN.no AS. All rights reserved.
//

import UIKit
import AVFoundation

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

    private let session = AVCaptureSession()
    private let captureQueue = dispatch_queue_create("no.finn.finjinon-captures", DISPATCH_QUEUE_SERIAL)
    private var cameraDevice: AVCaptureDevice!
    private var stillImageOutput: AVCaptureStillImageOutput!

    override init() {
        session.sessionPreset = AVCaptureSessionPresetPhoto
        previewLayer = AVCaptureVideoPreviewLayer.layerWithSession(session) as! AVCaptureVideoPreviewLayer
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
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
            connection.videoOrientation = AVCaptureVideoOrientation(rawValue: UIDevice.currentDevice().orientation.rawValue)!

            self.stillImageOutput.captureStillImageAsynchronouslyFromConnection(connection, completionHandler: { (sampleBuffer, error) in
                if error == nil {
                    let data = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer)
                    let metadata: NSDictionary = CMCopyDictionaryOfAttachments(nil, sampleBuffer, CMAttachmentMode(kCMAttachmentMode_ShouldPropagate)).takeUnretainedValue()

                    dispatch_async(dispatch_get_main_queue()) {
                        completion(data, metadata)
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
        if let idx = find(supportedFlashModes, flashMode) {
            nextIndex = idx + 1
        }
        let startIndex = min(nextIndex, supportedFlashModes.count)
        let next = supportedFlashModes[startIndex..<supportedFlashModes.count].first ?? supportedFlashModes.first

        return next
    }

    // MARK: - Private methods

    private func accessDeniedError(code: Int = FinjinonCameraAccessErrorDeniedCode) -> NSError {
        let info = [NSLocalizedDescriptionKey: NSLocalizedString("Camera access denied, please enable it in the Settings app to continue", comment: "")]
        return NSError(domain: FinjinonCameraAccessErrorDomain, code: code, userInfo: info)
    }

    private func lockCurrentCameraDeviceForConfiguration(configurator: AVCaptureDevice -> Void) {
        dispatch_async(captureQueue) {
            var error: NSError?
            if !self.cameraDevice.lockForConfiguration(&error) {
                NSLog("Failed to lock camera device for configuration: \(error)")
            }

            configurator(self.cameraDevice)

            self.cameraDevice.unlockForConfiguration()
        }
    }

    private func configure(completion: NSError? -> Void) {
        dispatch_async(captureQueue) {
            self.cameraDevice = self.cameraDeviceWithPosition(.Back)

            var error: NSError?
            if let input = AVCaptureDeviceInput.deviceInputWithDevice(self.cameraDevice, error: &error) as? AVCaptureDeviceInput {
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                } else {
                    // TODO handle?
                    NSLog("failed to add input \(input) to session \(self.session)")
                }
            } else {
                // TODO ?
                // self.delegate?.cameraManager(self, didError: error)
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
                var configLockError: NSError?
                self.cameraDevice.lockForConfiguration(&configLockError)
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
