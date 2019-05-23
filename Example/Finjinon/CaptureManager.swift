//
//  Copyright (c) 2017 FINN.no AS. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

enum CaptureManagerViewfinderMode {
    case fullScreen
    case window
}

class CaptureManager: NSObject {
    let previewLayer: AVCaptureVideoPreviewLayer
    var flashMode: AVCaptureDevice.FlashMode {
        return cameraDevice?.flashMode ?? .off
    }

    var hasFlash: Bool {
        return cameraDevice?.hasFlash ?? false && cameraDevice?.isFlashAvailable ?? false
    }

    var supportedFlashModes: [AVCaptureDevice.FlashMode] {
        var modes: [AVCaptureDevice.FlashMode] = []
        for mode in [AVCaptureDevice.FlashMode.off, AVCaptureDevice.FlashMode.auto, AVCaptureDevice.FlashMode.on] {
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
    private var lastVideoCaptureTime = CMTime()

    private lazy var lowLightDetector = LowLightDetector()
    weak var lowLightDetectorDelegate: LowLightDetectorDelegate? {
        didSet {
            lowLightDetector.delegate = lowLightDetectorDelegate
        }
    }

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

    func captureImage(_ completion: @escaping (Data, NSDictionary) -> Void) {
        captureQueue.async {
            guard let connection = self.stillImageOutput?.connection(with: AVMediaType.video) else {
                return
            }
            connection.videoOrientation = self.orientation

            self.stillImageOutput?.captureStillImageAsynchronously(from: connection, completionHandler: { sampleBuffer, error in
                if error == nil {
                    if let sampleBuffer = sampleBuffer, let data = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer) {
                        if let metadata = CMCopyDictionaryOfAttachments(allocator: nil, target: sampleBuffer, attachmentMode: CMAttachmentMode(kCMAttachmentMode_ShouldPropagate)) as NSDictionary? {
                            DispatchQueue.main.async {
                                completion(data, metadata)
                            }
                        } else {
                            print("failed creating metadata")
                        }
                    }
                } else {
                    NSLog("Failed capturing still images: \(String(describing: error))")
                }
            })
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
        lockCurrentCameraDeviceForConfiguration { device in
            if let device = device {
                device.flashMode = newMode
                DispatchQueue.main.async(execute: completion)
            }
        }
    }

    // Next available flash mode, or nil if flash is unsupported
    func nextAvailableFlashMode() -> AVCaptureDevice.FlashMode? {
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
    @objc func changedOrientationNotification(_: Notification?) {
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
                let input = try AVCaptureDeviceInput(device: self.cameraDevice!)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                } else {
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

            if self.session.canAddOutput(self.stillImageOutput!) {
                self.session.addOutput(self.stillImageOutput!)
            }

            let videoOutput = self.makeVideoDataOutput()

            if self.session.canAddOutput(videoOutput) {
                self.session.addOutput(videoOutput)
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

    fileprivate func cameraDeviceWithPosition(_ position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let availableCameraDevices = AVCaptureDevice.devices(for: AVMediaType.video)
        for device in availableCameraDevices {
            if device.position == position {
                return device
            }
        }

        return AVCaptureDevice.default(for: AVMediaType.video)
    }

    private func makeVideoDataOutput() -> AVCaptureVideoDataOutput {
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "no.finn.finjinon-sample-buffer"))
        return output
    }
}

extension CaptureManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let fps: Int32 = 1 // Create pixel buffer and call the delegate 1 times per second

        guard (time - lastVideoCaptureTime) >= CMTime.init(value: 1, timescale: fps) else {
            return
        }

        lastVideoCaptureTime = time
        lowLightDetector.check(sampleBuffer: sampleBuffer)


        //let brightness = getBrightness(sampleBuffer: sampleBuffer)
        //print("Brightness: \(brightness)")
    }
}

protocol LowLightDetectorDelegate: AnyObject {
    // exposure value
    func lowLightDetector(_ detector: LowLightDetector, didDetectLuminosity: Double)
}

final class LowLightDetector {
    enum ClassificationResult: String {
        case low = "Low"
        case normal = "Normal"
    }

    weak var delegate: LowLightDetectorDelegate?
    private var visionRequest: Any?
    private var lastLuminosity: Double?

    init() {
        if #available(iOS 11.0, *) {
            //setupVision()
        }
    }

    func check(sampleBuffer: CMSampleBuffer) {
        let luminosity = getLuminosity(from: sampleBuffer)
        delegate?.lowLightDetector(self, didDetectLuminosity: luminosity)
    }

//    func classify(sampleBuffer: CMSampleBuffer) {
//        let luminosity = getLuminosity(from: sampleBuffer)
//        lastLuminosity = luminosity
//
//        if #available(iOS 11.0, *) {
//            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer), let request = visionRequest as? VNRequest else {
//                delegate?.lowLightDetector(self, didDetectLuminosity: luminosity, classificationResult: nil)
//                return
//            }
//
//            var requestOptions = [VNImageOption: Any]()
//
//            let attachment = CMGetAttachment(
//                sampleBuffer,
//                key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix,
//                attachmentModeOut: nil
//            )
//
//            if let cameraIntrinsicData = attachment {
//                requestOptions = [.cameraIntrinsics: cameraIntrinsicData]
//            }
//
//            do {
//                let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: requestOptions)
//                try imageRequestHandler.perform([request])
//            } catch {
//                delegate?.lowLightDetector(self, didDetectLuminosity: luminosity, classificationResult: nil)
//            }
//        }
//    }
//
//    @available(iOS 11.0, *)
//    private func setupVision() {
//        do {
//            let model = try VNCoreMLModel(for: ImageClassifier().model)
//            let request = VNCoreMLRequest(model: model, completionHandler: handleClassification)
//            request.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop
//            visionRequest = request
//        } catch {}
//    }
//
//    @available(iOS 11.0, *)
//    @objc private func handleClassification(request: VNRequest, error: Error?) {
//        guard let observations = request.results as? [VNClassificationObservation] else {
//            return
//        }
//
//        let result = observations.first(where: { $0.confidence > 0.9 }).flatMap({
//            ClassificationResult(rawValue: $0.identifier)
//        })
//
//
//        if let luminosity = lastLuminosity {
//            delegate?.lowLightDetector(self, didDetectLuminosity: luminosity, classificationResult: result?.rawValue)
//        }
//    }

    private func getLuminosity(from sampleBuffer: CMSampleBuffer) -> Double {
        let rawMetadata = CMCopyDictionaryOfAttachments(
            allocator: nil,
            target: sampleBuffer,
            attachmentMode: CMAttachmentMode(kCMAttachmentMode_ShouldPropagate)
        )
        let metadata = CFDictionaryCreateMutableCopy(nil, 0, rawMetadata) as NSMutableDictionary
        let exifData = metadata.value(forKey: "{Exif}") as? NSMutableDictionary

        let fNumber : Double = exifData?[kCGImagePropertyExifFNumber] as! Double
        let exposureTime : Double = exifData?[kCGImagePropertyExifExposureTime] as! Double
        let isoSpeedRatingsArray = exifData![kCGImagePropertyExifISOSpeedRatings] as? NSArray
        let isoSpeedRating : Double = isoSpeedRatingsArray![0] as! Double

        return log2((100 * fNumber * fNumber) / (exposureTime * isoSpeedRating))
    }
}
