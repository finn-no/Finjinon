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

    // Prepares the capture session, possibly asking the user for camera access.
    func prepare(completion: Void -> Void) {
        let authorizationStatus = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)
        switch authorizationStatus {
        case .Authorized:
            configure(completion)
        case .NotDetermined:
            AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo, completionHandler: { granted in
                if granted {
                    self.configure(completion)
                } else {
                    self.presentAccessDeniedAlert()
                }
            })
        case .Denied, .Restricted:
            presentAccessDeniedAlert()
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

    // MARK: - Private methods

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

    private func presentAccessDeniedAlert() {
        // TODO: present alert
        dispatch_async(dispatch_get_main_queue()) {
            let alert = UIAlertView(title: nil, message: "denied", delegate: nil, cancelButtonTitle: "OK")
            alert.show()
        }
    }

    private func configure(completion: Void -> Void) {
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

            self.session.startRunning()

            dispatch_async(dispatch_get_main_queue(), completion)
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
