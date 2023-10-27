//
//  Copyright (c) 2017 FINN.no AS. All rights reserved.
//

import UIKit
import AVFoundation
import MobileCoreServices
import Photos

public let FinjinonCameraAccessErrorDomain = "FinjinonCameraAccessErrorDomain"
public let FinjinonCameraAccessErrorDeniedCode = 1
public let FinjinonCameraAccessErrorDeniedInitialRequestCode = 2
public let FinjinonLibraryAccessErrorDomain = "FinjinonLibraryAccessErrorDomain"

public protocol PhotoCaptureViewControllerDelegate: NSObjectProtocol {
    func photoCaptureViewControllerDidFinish(_ controller: PhotoCaptureViewController)
    func photoCaptureViewController(_ controller: PhotoCaptureViewController, didSelectAssetAtIndexPath indexPath: IndexPath)
    func photoCaptureViewController(_ controller: PhotoCaptureViewController, didFailWithError error: NSError)

    func photoCaptureViewController(_ controller: PhotoCaptureViewController, cellForItemAtIndexPath indexPath: IndexPath) -> PhotoCollectionViewCell?
    func photoCaptureViewController(_ controller: PhotoCaptureViewController, didMoveItemFromIndexPath fromIndexPath: IndexPath, toIndexPath: IndexPath)

    func photoCaptureViewControllerNumberOfAssets(_ controller: PhotoCaptureViewController) -> Int
    func photoCaptureViewController(_ controller: PhotoCaptureViewController, assetForIndexPath indexPath: IndexPath) -> Asset
    // delegate is responsible for updating own data structure to include new asset at the tip when one is added,
    // eg photoCaptureViewControllerNumberOfAssets should be +1 after didAddAsset is called
    func photoCaptureViewController(_ controller: PhotoCaptureViewController, didAddAsset asset: Asset)
    func photoCaptureViewController(_ controller: PhotoCaptureViewController, deleteAssetAtIndexPath indexPath: IndexPath)
    func photoCaptureViewController(_ controller: PhotoCaptureViewController, canMoveItemAtIndexPath indexPath: IndexPath) -> Bool
}

open class PhotoCaptureViewController: UIViewController, PhotoCollectionViewLayoutDelegate {
    open weak var delegate: PhotoCaptureViewControllerDelegate?
    /// Optional instance confirming to the ImagePickerAdapter-protocol to allow selecting an image from the library.
    /// The default implementation will present a UIImagePickerController. Setting this to nil, will remove the library-button.
    open var imagePickerAdapter: ImagePickerAdapter? = ImagePickerControllerAdapter() {
        didSet {
            updateImagePickerButton()
        }
    }

    /// Optional view to display when returning from imagePicker not finished retrieving data.
    /// Use constraints to position elements dynamically, as the view will be rotated and sized with the device.
    open var imagePickerWaitingForImageDataView: UIView?

    fileprivate let storage = PhotoStorage()
    fileprivate let captureManager = CaptureManager()
    fileprivate var previewView = UIView()
    fileprivate var captureButton = TriggerButton()
    fileprivate let collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout())
    fileprivate var containerView = UIView()
    fileprivate var focusIndicatorView = UIView(frame: CGRect(x: 0, y: 0, width: 64, height: 64))
    fileprivate var flashButton = UIButton()
    fileprivate var pickerButton: UIButton?
    fileprivate var closeButton = UIButton()
    fileprivate let buttonMargin: CGFloat = 12
    fileprivate var orientation: UIDeviceOrientation = .portrait

    private lazy var lowLightView: LowLightView = {
        let view = LowLightView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private var viewFrame = CGRect.zero
    private var viewBounds = CGRect.zero
    private var subviewSetupDone = false

    deinit {
        captureManager.stop(nil)
        NotificationCenter.default.removeObserver(self)
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.black

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOrientationChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Setting subviews in viewDidAppear is not a great solution... It's a fix to respect Safe Areas (known after
        // viewDidAppear) for iPhone X in particular. Setting positions constrained to Safe Area would allow for more
        // flexibility with Auto Layout, and thus creating the subViews in viewDidLoad/viewWillAppear would be possible again.

        if #available(iOS 11.0, *) {
            view.insetsLayoutMarginsFromSafeArea = true
            viewFrame = view.convert(view.safeAreaLayoutGuide.layoutFrame, to: view.superview ?? view)
            viewBounds = view.safeAreaLayoutGuide.layoutFrame
        } else {
            viewFrame = view.frame
            viewBounds = view.bounds
        }
        setupSubviews()

        collectionView.reloadData()
        scrollToLastAddedAssetAnimated(false)
    }

    func setupSubviews() {
        // Subviews need to be added and framed during viewDidAppear for the iPhone X's safeAreas to be known.
        if subviewSetupDone { return }
        subviewSetupDone = true

        previewView.frame = viewBounds
        previewView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(previewView)
        let previewLayer = captureManager.previewLayer
        // We are using AVCaptureSessionPresetPhoto which has a 4:3 aspect ratio
        let viewFinderWidth = viewBounds.size.width
        var viewFinderHeight = (viewFinderWidth / 3) * 4
        if captureManager.viewfinderMode == .fullScreen {
            viewFinderHeight = viewBounds.size.height
        }
        previewLayer.frame = CGRect(x: 0, y: 0, width: viewFinderWidth, height: viewFinderHeight)
        previewView.layer.addSublayer(previewLayer)

        focusIndicatorView.backgroundColor = UIColor.clear
        focusIndicatorView.layer.borderColor = UIColor.orange.cgColor
        focusIndicatorView.layer.borderWidth = 1.0
        focusIndicatorView.alpha = 0.0
        previewView.addSubview(focusIndicatorView)

        var buttonFrame = CGRect(x: viewFrame.origin.x + buttonMargin, y: viewFrame.origin.y + buttonMargin, width: 70, height: 38)
        flashButton.frame = buttonFrame

        let icon = UIImage(named: "LightningIcon", in: Bundle.finjinon, compatibleWith: nil)
        flashButton.setImage(icon, for: .normal)
        flashButton.setTitle("finjinon.auto".localized(), for: .normal)
        flashButton.addTarget(self, action: #selector(flashButtonTapped(_:)), for: .touchUpInside)
        flashButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .footnote)
        flashButton.tintColor = UIColor.white
        flashButton.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        roundifyButton(flashButton, inset: 14)
        flashButton.sizeToFit()
        buttonFrame.size.width = max(flashButton.frame.size.width + 35, 70)
        flashButton.frame = buttonFrame

        let tapper = UITapGestureRecognizer(target: self, action: #selector(focusTapGestureRecognized(_:)))
        previewView.addGestureRecognizer(tapper)

        var collectionViewHeight: CGFloat = min(viewFrame.size.height / 6, 120)
        let collectionViewBottomMargin: CGFloat = 70
        let cameraButtonHeight: CGFloat = 66

        var containerFrame = CGRect(x: viewFrame.origin.x, y: viewFrame.origin.y + viewBounds.height - collectionViewBottomMargin - collectionViewHeight, width: viewBounds.width, height: collectionViewBottomMargin + collectionViewHeight)
        if captureManager.viewfinderMode == .window {
            let containerHeight = viewFrame.height - viewFinderHeight
            containerFrame.origin.y = viewFrame.origin.y + viewFrame.height - containerHeight
            containerFrame.size.height = containerHeight
            collectionViewHeight = containerHeight - cameraButtonHeight
        }
        containerView.frame = containerFrame
        containerView.backgroundColor = UIColor(white: 0, alpha: 0.4)
        view.addSubview(containerView)
        collectionView.frame = CGRect(x: 0, y: 0, width: containerView.bounds.width, height: collectionViewHeight)
        let layout = PhotoCollectionViewLayout()
        layout.delegate = self
        collectionView.collectionViewLayout = layout

        layout.scrollDirection = .horizontal
        let inset: CGFloat = 8
        layout.itemSize = CGSize(width: collectionView.frame.height - (inset * 2), height: collectionView.frame.height - (inset * 2))
        layout.sectionInset = UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
        layout.minimumInteritemSpacing = inset
        layout.minimumLineSpacing = inset
        layout.didReorderHandler = { [weak self] fromIndexPath, toIndexPath in
            if let welf = self {
                welf.delegate?.photoCaptureViewController(welf, didMoveItemFromIndexPath: fromIndexPath as IndexPath, toIndexPath: toIndexPath as IndexPath)
            }
        }

        collectionView.backgroundColor = UIColor.clear
        collectionView.alwaysBounceHorizontal = true
        containerView.addSubview(collectionView)
        collectionView.register(PhotoCollectionViewCell.self, forCellWithReuseIdentifier: "PhotoCell")
        collectionView.dataSource = self
        collectionView.delegate = self

        captureButton.frame = CGRect(x: (containerView.frame.width / 2) - cameraButtonHeight / 2, y: containerView.frame.height - cameraButtonHeight - 4, width: cameraButtonHeight, height: cameraButtonHeight)
        captureButton.layer.cornerRadius = cameraButtonHeight / 2
        captureButton.addTarget(self, action: #selector(capturePhotoTapped(_:)), for: .touchUpInside)
        containerView.addSubview(captureButton)
        captureButton.isEnabled = false
        captureButton.accessibilityLabel = "finjinon.captureButton".localized()

        closeButton.frame = CGRect(x: captureButton.frame.maxX, y: captureButton.frame.midY - 22, width: viewBounds.width - captureButton.frame.maxX, height: 44)
        closeButton.addTarget(self, action: #selector(doneButtonTapped(_:)), for: .touchUpInside)
        closeButton.setTitle("finjinon.done".localized(), for: .normal)
        closeButton.tintColor = UIColor.white
        closeButton.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        containerView.addSubview(closeButton)

        view.addSubview(lowLightView)
        NSLayoutConstraint.activate([
            lowLightView.bottomAnchor.constraint(equalTo: collectionView.topAnchor, constant: -16),
            lowLightView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            lowLightView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8)
        ])

        updateImagePickerButton()

        previewView.alpha = 0.0
        captureManager.prepare { error in
            if let error = error {
                self.delegate?.photoCaptureViewController(self, didFailWithError: error)
                return
            }

            if self.captureManager.hasFlash {
                self.view.addSubview(self.flashButton)
            }

            UIView.animate(withDuration: 0.2, animations: {
                self.captureButton.isEnabled = true
                self.previewView.alpha = 1.0
            })
        }

        captureManager.delegate = self
    }

    private func updateImagePickerButton() {
        if imagePickerAdapter == nil {
            if pickerButton != nil {
                pickerButton?.removeFromSuperview()
                pickerButton = nil
            }
        } else {
            let pickerButtonWidth: CGFloat = 114
            let buttonRect = CGRect(x: viewFrame.width - pickerButtonWidth - buttonMargin, y: viewFrame.origin.y + buttonMargin, width: pickerButtonWidth, height: 38)

            if pickerButton == nil {
                pickerButton = UIButton(frame: buttonRect)
                pickerButton!.setTitle("finjinon.photos".localized(), for: .normal)
                let icon = UIImage(named: "PhotosIcon", in: Bundle.finjinon, compatibleWith: nil)
                pickerButton!.setImage(icon, for: .normal)
                pickerButton!.addTarget(self, action: #selector(presentImagePickerTapped(_:)), for: .touchUpInside)
                pickerButton!.titleLabel?.font = UIFont.preferredFont(forTextStyle: .footnote)
                pickerButton!.autoresizingMask = [.flexibleTopMargin]
                pickerButton!.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                roundifyButton(pickerButton!)
                view.addSubview(pickerButton!)
            } else {
                pickerButton!.frame = buttonRect
            }
            view.bringSubviewToFront(pickerButton!)
        }
    }

    open override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .slide
    }

    open override var prefersStatusBarHidden: Bool {
        return true
    }

    open override var shouldAutorotate: Bool {
        return false
    }

    open override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.portrait
    }

    // MARK: - API

    open func registerClass(_ cellClass: AnyClass?, forCellWithReuseIdentifier identifier: String) {
        collectionView.register(cellClass, forCellWithReuseIdentifier: identifier)
    }

    open func dequeuedReusableCellForClass<T: PhotoCollectionViewCell>(_ clazz: T.Type, indexPath: IndexPath, config: ((T) -> Void)) -> T {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: clazz.cellIdentifier(), for: indexPath) as! T
        config(cell)
        return cell
    }

    open func reloadPreviewItemsAtIndexes(_ indexes: [Int]) {
        let indexPaths = indexes.map { IndexPath(item: $0, section: 0) }
        collectionView.reloadItems(at: indexPaths)
    }

    open func reloadPreviews() {
        collectionView.reloadData()
    }

    open func selectedPreviewIndexPath() -> IndexPath? {
        if let selection = collectionView.indexPathsForSelectedItems {
            return selection.first
        }

        return nil
    }

    open func cellForpreviewAtIndexPath<T: PhotoCollectionViewCell>(_ indexPath: IndexPath) -> T? {
        return collectionView.cellForItem(at: indexPath) as? T
    }

    /// returns the rect in view (minus the scroll offset) of the thumbnail at the given indexPath.
    /// Useful for presenting sheets etc from the thumbnail
    open func previewRectForIndexPath(_ indexPath: IndexPath) -> CGRect {
        if let attributes = collectionView.layoutAttributesForItem(at: indexPath) {
            var rect = attributes.frame
            rect.origin.x -= collectionView.contentOffset.x
            rect.origin.y -= collectionView.contentOffset.y
            return view.convert(rect, from: collectionView.superview)
        }
        return CGRect.zero
    }

    open func createAssetFromImageData(_ data: Data, completion: @escaping (Asset) -> Void) {
        storage.createAssetFromImageData(data, completion: completion)
    }

    open func createAssetFromImage(_ image: UIImage, completion: @escaping (Asset) -> Void) {
        storage.createAssetFromImage(image, completion: completion)
    }

    open func createAssetFromImageURL(_ imageURL: URL, dimensions: CGSize, completion: @escaping (Asset) -> Void) {
        storage.createAssetFromImageURL(imageURL, dimensions: dimensions, completion: completion)
    }

    /// Deletes item at the given index. Perform any deletions from datamodel in the handler
    open func deleteAssetAtIndex(_ idx: Int, handler: @escaping () -> Void) {
        let indexPath = IndexPath(item: idx, section: 0)
        if let asset = delegate?.photoCaptureViewController(self, assetForIndexPath: indexPath) {
            collectionView.performBatchUpdates({
                handler()
                self.collectionView.deleteItems(at: [indexPath])
            }, completion: { _ in
                if asset.imageURL == nil {
                    self.storage.deleteAsset(asset, completion: {})
                }
            })
        }
    }

    open func libraryAuthorizationStatus() -> PHAuthorizationStatus {
        return PHPhotoLibrary.authorizationStatus()
    }

    open func cameraAuthorizationStatus() -> AVAuthorizationStatus {
        return captureManager.authorizationStatus()
    }

    // MARK: - Actions

    @objc private func handleOrientationChange() {
        switch UIDevice.current.orientation {
        case .landscapeLeft, .landscapeRight, .portrait, .portraitUpsideDown:
            self.orientation = UIDevice.current.orientation
            self.updateWidgetsToOrientation()
        case .faceDown, .faceUp, .unknown:
            break
        @unknown default:
            break
        }
    }

    @objc func flashButtonTapped(_: UIButton) {
        let mode = captureManager.nextAvailableFlashMode() ?? .off
        captureManager.changeFlashMode(mode) {
            switch mode {
            case .off:
                self.flashButton.setTitle("finjinon.off".localized(), for: .normal)
            case .on:
                self.flashButton.setTitle("finjinon.on".localized(), for: .normal)
            case .auto:
                self.flashButton.setTitle("finjinon.auto".localized(), for: .normal)
            @unknown default:
                break
            }
        }
    }

    @objc func presentImagePickerTapped(_: AnyObject) {
        if libraryAuthorizationStatus() == .denied || libraryAuthorizationStatus() == .restricted {
            let error = NSError(domain: FinjinonLibraryAccessErrorDomain, code: 0, userInfo: nil)
            delegate?.photoCaptureViewController(self, didFailWithError: error)
            return
        }

        guard let controller = imagePickerAdapter?.viewControllerForImageSelection({ assets in
            if let waitView = self.imagePickerWaitingForImageDataView, assets.count > 0 {
                waitView.translatesAutoresizingMaskIntoConstraints = false
                self.view.addSubview(waitView)

                waitView.removeConstraints(waitView.constraints.filter({ (constraint: NSLayoutConstraint) -> Bool in
                    constraint.secondItem as? UIView == self.view
                }))
                self.view.addConstraint(NSLayoutConstraint(item: waitView, attribute: .centerX, relatedBy: .equal, toItem: self.view, attribute: .centerX, multiplier: 1, constant: 0))
                self.view.addConstraint(NSLayoutConstraint(item: waitView, attribute: .centerY, relatedBy: .equal, toItem: self.view, attribute: .centerY, multiplier: 1, constant: 0))

                switch UIDevice.current.orientation {
                case .landscapeRight:
                    self.view.addConstraint(NSLayoutConstraint(item: waitView, attribute: .height, relatedBy: .equal, toItem: self.view, attribute: .width, multiplier: 1, constant: 0))
                    self.view.addConstraint(NSLayoutConstraint(item: waitView, attribute: .width, relatedBy: .equal, toItem: self.view, attribute: .height, multiplier: 1, constant: 0))

                case .landscapeLeft:
                    self.view.addConstraint(NSLayoutConstraint(item: waitView, attribute: .height, relatedBy: .equal, toItem: self.view, attribute: .width, multiplier: 1, constant: 0))
                    self.view.addConstraint(NSLayoutConstraint(item: waitView, attribute: .width, relatedBy: .equal, toItem: self.view, attribute: .height, multiplier: 1, constant: 0))

                default:
                    self.view.addConstraint(NSLayoutConstraint(item: waitView, attribute: .height, relatedBy: .equal, toItem: self.view, attribute: .height, multiplier: 1, constant: 0))
                    self.view.addConstraint(NSLayoutConstraint(item: waitView, attribute: .width, relatedBy: .equal, toItem: self.view, attribute: .width, multiplier: 1, constant: 0))
                }
                waitView.rotateToCurrentDeviceOrientation()
            }

            let resolver = AssetResolver()
            var count = assets.count
            assets.forEach { asset in
                resolver.enqueueResolve(asset, completion: { image in
                    self.createAssetFromImage(image, completion: { (asset: Asset) in
                        var mutableAsset = asset
                        mutableAsset.imageDataSourceType = .library
                        self.didAddAsset(mutableAsset)

                        count -= 1
                        if count == 0 {
                            self.imagePickerWaitingForImageDataView?.removeFromSuperview()
                        }
                    })
                })
            }
        }, completion: { _ in
            DispatchQueue.main.async {
                self.dismiss(animated: true, completion: nil)
            }
        }) else {
            return
        }

        present(controller, animated: true, completion: nil)
    }

    @objc func capturePhotoTapped(_ sender: UIButton) {
        sender.isEnabled = false
        UIView.animate(withDuration: 0.1, animations: { self.previewView.alpha = 0.0 }, completion: { _ in
            UIView.animate(withDuration: 0.1, animations: { self.previewView.alpha = 1.0 })
        })

        captureManager.captureImage()
    }

    fileprivate func didAddAsset(_ asset: Asset) {
        DispatchQueue.main.async {
            self.collectionView.performBatchUpdates({
                self.delegate?.photoCaptureViewController(self, didAddAsset: asset)
                let insertedIndexPath: IndexPath
                if let count = self.delegate?.photoCaptureViewControllerNumberOfAssets(self) {
                    insertedIndexPath = IndexPath(item: count - 1, section: 0)
                } else {
                    insertedIndexPath = IndexPath(item: 0, section: 0)
                }
                self.collectionView.insertItems(at: [insertedIndexPath])
            }, completion: { _ in
                self.scrollToLastAddedAssetAnimated(true)
            })
        }
    }

    fileprivate func scrollToLastAddedAssetAnimated(_ animated: Bool) {
        if let count = self.delegate?.photoCaptureViewControllerNumberOfAssets(self), count > 0 {
            collectionView.scrollToItem(at: IndexPath(item: count - 1, section: 0), at: .left, animated: animated)
        }
    }

    @objc func doneButtonTapped(_: UIButton) {
        delegate?.photoCaptureViewControllerDidFinish(self)
        imagePickerAdapter = nil

        dismiss(animated: true, completion: nil)
    }

    @objc func focusTapGestureRecognized(_ gestureRecognizer: UITapGestureRecognizer) {
        if gestureRecognizer.state == .ended {
            let point = gestureRecognizer.location(in: gestureRecognizer.view)

            focusIndicatorView.center = point
            UIView.animate(withDuration: 0.3, delay: 0.0, options: .beginFromCurrentState, animations: {
                self.focusIndicatorView.alpha = 1.0
            }, completion: { _ in
                UIView.animate(withDuration: 0.2, delay: 1.6, options: .beginFromCurrentState, animations: {
                    self.focusIndicatorView.alpha = 0.0
                }, completion: nil)
            })

            captureManager.lockFocusAtPointOfInterest(point)
        }
    }

    // MARK: - PhotoCollectionViewLayoutDelegate

    open func photoCollectionViewLayout(_: UICollectionViewLayout, canMoveItemAtIndexPath indexPath: IndexPath) -> Bool {
        return delegate?.photoCaptureViewController(self, canMoveItemAtIndexPath: indexPath) ?? true
    }

    // MARK: - Private methods

    fileprivate func roundifyButton(_ button: UIButton, inset: CGFloat = 16) {
        button.tintColor = UIColor.white

        button.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        button.layer.borderColor = button.tintColor!.cgColor
        button.layer.borderWidth = 1.0
        button.layer.cornerRadius = button.bounds.height / 2

        var insets = button.imageEdgeInsets
        insets.left -= inset
        button.imageEdgeInsets = insets
    }

    fileprivate func updateWidgetsToOrientation() {
        var flashPosition = flashButton.frame.origin
        var pickerPosition: CGPoint = pickerButton?.frame.origin ?? .zero
        if orientation == .landscapeLeft || orientation == .landscapeRight {
            flashPosition = CGPoint(x: viewFrame.origin.x + buttonMargin - (buttonMargin / 3), y: viewFrame.origin.y + buttonMargin)
            pickerPosition = pickerButton != nil ? CGPoint(x: viewFrame.origin.x + viewBounds.width - (pickerButton!.bounds.size.width / 2 - buttonMargin), y: viewFrame.origin.y + buttonMargin) : .zero
        } else if orientation == .portrait || orientation == .portraitUpsideDown {
            pickerPosition = pickerButton != nil ? CGPoint(x: viewFrame.origin.x + viewBounds.width - (pickerButton!.bounds.size.width + buttonMargin), y: viewFrame.origin.y + buttonMargin) : .zero
            flashPosition = CGPoint(x: viewFrame.origin.x + buttonMargin, y: viewFrame.origin.y + buttonMargin)
        }
        let animations = {
            self.pickerButton?.rotateToCurrentDeviceOrientation()
            self.pickerButton?.frame.origin = pickerPosition
            self.flashButton.rotateToCurrentDeviceOrientation()
            self.flashButton.frame.origin = flashPosition
            self.closeButton.rotateToCurrentDeviceOrientation()

            for cell in self.collectionView.visibleCells {
                cell.contentView.rotateToCurrentDeviceOrientation()
            }
        }
        UIView.animate(withDuration: 0.25, animations: animations)
    }
}

extension PhotoCaptureViewController: UICollectionViewDataSource, PhotoCollectionViewCellDelegate {
    public func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        return delegate?.photoCaptureViewControllerNumberOfAssets(self) ?? 0
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: PhotoCollectionViewCell
        if let delegateCell = delegate?.photoCaptureViewController(self, cellForItemAtIndexPath: indexPath) {
            cell = delegateCell
        } else {
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: PhotoCollectionViewCell.cellIdentifier(), for: indexPath) as! PhotoCollectionViewCell
        }
        // This cannot use the currentRotation call as it might be called when .FaceUp or .FaceDown is device-orientation
        cell.contentView.rotateToDeviceOrientation(orientation)
        cell.delegate = self
        return cell
    }

    func collectionViewCellDidTapDelete(_ cell: PhotoCollectionViewCell) {
        if let indexPath = collectionView.indexPath(for: cell) {
            deleteAssetAtIndex(indexPath.item, handler: {
                self.delegate?.photoCaptureViewController(self, deleteAssetAtIndexPath: indexPath)
            })
        }
    }
}

extension PhotoCaptureViewController: UICollectionViewDelegate {
    public func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.photoCaptureViewController(self, didSelectAssetAtIndexPath: indexPath)
    }
}

extension PhotoCaptureViewController: CaptureManagerDelegate {
    func captureManager(_ manager: CaptureManager, didCaptureImageData data: Data?, withMetadata metadata: NSDictionary?) {
        guard let data = data else { return }

        captureButton.isEnabled = true

        createAssetFromImageData(data as Data, completion: { [weak self] (asset: Asset) in
            guard let self = self else { return }
            var mutableAsset = asset
            mutableAsset.imageDataSourceType = .camera
            self.didAddAsset(mutableAsset)
        })
    }

    func captureManager(_ manager: CaptureManager, didDetectLightingCondition lightingCondition: LightingCondition) {
        if lightingCondition == .low {
            lowLightView.text = "finjinon.lowLightMessage".localized()
            lowLightView.isHidden = false
        } else {
            lowLightView.text = nil
            lowLightView.isHidden = true
        }
    }
    
    func captureManager(_ manager: CaptureManager, didFailWithError error: NSError) {
        print("Failure: \(error)")
    }
}

extension UIView {
    public func rotateToCurrentDeviceOrientation() {
        rotateToDeviceOrientation(UIDevice.current.orientation)
    }

    public func rotateToDeviceOrientation(_ orientation: UIDeviceOrientation) {
        switch orientation {
        case .faceDown, .faceUp, .unknown:
            ()
        case .landscapeLeft:
            transform = CGAffineTransform(rotationAngle: CGFloat(Double.pi / 2))
        case .landscapeRight:
            transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi / 2))
        case .portrait, .portraitUpsideDown:
            transform = CGAffineTransform(rotationAngle: 0)
        @unknown default:
            return
        }
    }
}
