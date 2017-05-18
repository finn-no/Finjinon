//
//  PhotoCaptureViewController.swift
//  Finjinon
//
//  Created by Sørensen, Johan on 05.06.15.
//  Copyright (c) 2015 FINN.no AS. All rights reserved.
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
    open var imagePickerAdapter: ImagePickerAdapter = ImagePickerControllerAdapter()
    
    /// Optional view to display when returning from imagePicker not finished retrieving data.
    /// Use constraints to position elements dynamically, as the view will be rotated and sized with the device.
    open var imagePickerWaitingForImageDataView: UIView?

    fileprivate let storage = PhotoStorage()
    fileprivate let captureManager = CaptureManager()
    fileprivate var previewView: UIView!
    fileprivate var captureButton: TriggerButton!
    fileprivate let collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout())
    fileprivate var containerView: UIView!
    fileprivate var focusIndicatorView: UIView!
    fileprivate var flashButton: UIButton!
    fileprivate var pickerButton : UIButton!
    fileprivate var closeButton : UIButton!
    fileprivate let buttonMargin : CGFloat = 12
    fileprivate var orientation : UIDeviceOrientation = .portrait

    deinit {
        captureManager.stop(nil)
    }

    override open func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.black

        // TODO: Move all the boring view setup to a storyboard/xib

        previewView = UIView(frame: view.bounds)
        previewView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(previewView)
        let previewLayer = captureManager.previewLayer
        // We are using AVCaptureSessionPresetPhoto which has a 4:3 aspect ratio
        let viewFinderWidth = view.bounds.size.width
        var viewFinderHeight = (viewFinderWidth/3) * 4
        if captureManager.viewfinderMode == .fullScreen {
            viewFinderHeight = view.bounds.size.height
        }
        previewLayer.frame = CGRect(x: 0, y: 0, width: viewFinderWidth, height: viewFinderHeight)
        previewView.layer.addSublayer(previewLayer)

        focusIndicatorView = UIView(frame: CGRect(x: 0, y: 0, width: 64, height: 64))
        focusIndicatorView.backgroundColor = UIColor.clear
        focusIndicatorView.layer.borderColor = UIColor.orange.cgColor
        focusIndicatorView.layer.borderWidth = 1.0
        focusIndicatorView.alpha = 0.0
        previewView.addSubview(focusIndicatorView)

        flashButton = UIButton(frame: CGRect(x: buttonMargin, y: buttonMargin, width: 70, height: 38))
        flashButton.setImage(UIImage(named: "LightningIcon"), for: UIControlState())
        flashButton.setTitle(NSLocalizedString("Off", comment:"flash off"), for: UIControlState())
        flashButton.addTarget(self, action: #selector(flashButtonTapped(_:)), for: .touchUpInside)
        flashButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.footnote)
        flashButton.tintColor = UIColor.white
        flashButton.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        roundifyButton(flashButton, inset: 14)

        let tapper = UITapGestureRecognizer(target: self, action: #selector(focusTapGestureRecognized(_:)))
        previewView.addGestureRecognizer(tapper)

        var collectionViewHeight: CGFloat = min(view.frame.size.height/6, 120)
        let collectionViewBottomMargin : CGFloat = 70
        let cameraButtonHeight : CGFloat = 66

        var containerFrame = CGRect(x: 0, y: view.frame.height-collectionViewBottomMargin-collectionViewHeight, width: view.frame.width, height: collectionViewBottomMargin+collectionViewHeight)
        if captureManager.viewfinderMode == .window {
            let containerHeight = view.frame.height - viewFinderHeight
            containerFrame.origin.y = view.frame.height - containerHeight
            containerFrame.size.height = containerHeight
            collectionViewHeight = containerHeight - cameraButtonHeight
        }
        containerView = UIView(frame: containerFrame)
        containerView.backgroundColor = UIColor(white: 0, alpha: 0.4)
        view.addSubview(containerView)
        collectionView.frame = CGRect(x: 0, y: 0, width: containerView.bounds.width, height: collectionViewHeight)
        let layout = PhotoCollectionViewLayout()
        layout.delegate = self
        collectionView.collectionViewLayout = layout

        layout.scrollDirection = .horizontal
        let inset: CGFloat = 8
        layout.itemSize = CGSize(width: collectionView.frame.height - (inset*2), height: collectionView.frame.height - (inset*2))
        layout.sectionInset = UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
        layout.minimumInteritemSpacing = inset
        layout.minimumLineSpacing = inset
        layout.didReorderHandler = { [weak self] (fromIndexPath, toIndexPath) in
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

        captureButton = TriggerButton(frame: CGRect(x: (containerView.frame.width/2)-cameraButtonHeight/2, y: containerView.frame.height - cameraButtonHeight - 4, width: cameraButtonHeight, height: cameraButtonHeight))
        captureButton.layer.cornerRadius = cameraButtonHeight/2
        captureButton.addTarget(self, action: #selector(capturePhotoTapped(_:)), for: .touchUpInside)
        containerView.addSubview(captureButton)
        captureButton.isEnabled = false
        captureButton.accessibilityLabel = NSLocalizedString("Take a picture", comment: "")

        closeButton = UIButton(frame: CGRect(x: captureButton.frame.maxX, y: captureButton.frame.midY - 22, width: view.bounds.width - captureButton.frame.maxX, height: 44))
        closeButton.addTarget(self, action: #selector(doneButtonTapped(_:)), for: .touchUpInside)
        closeButton.setTitle(NSLocalizedString("Done", comment: ""), for: UIControlState())
        closeButton.tintColor = UIColor.white
        closeButton.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        containerView.addSubview(closeButton)

        let pickerButtonWidth: CGFloat = 114
        pickerButton = UIButton(frame: CGRect(x: view.bounds.width - pickerButtonWidth - buttonMargin, y: buttonMargin, width: pickerButtonWidth, height: 38))
        pickerButton.setTitle(NSLocalizedString("Photos", comment: "Select from Photos buttont itle"), for: UIControlState())
        pickerButton.setImage(UIImage(named: "PhotosIcon"), for: UIControlState())
        pickerButton.addTarget(self, action: #selector(presentImagePickerTapped(_:)), for: .touchUpInside)
        pickerButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.footnote)
        pickerButton.autoresizingMask = [.flexibleTopMargin]
        pickerButton.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        roundifyButton(pickerButton)
        view.addSubview(pickerButton)

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

        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIDeviceOrientationDidChange, object: nil, queue: nil) { (NSNotification) -> Void in
            switch UIDevice.current.orientation {
            case .faceDown, .faceUp, .unknown:
                ()
            case .landscapeLeft, .landscapeRight, .portrait, .portraitUpsideDown:
                self.orientation = UIDevice.current.orientation
                self.updateWidgetsToOrientation()
            }
        }
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        collectionView.reloadData()

        scrollToLastAddedAssetAnimated(false)

        // In case the application uses the old style for managing status bar appearance
        UIApplication.shared.setStatusBarHidden(true, with: .slide)
    }

    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        UIApplication.shared.setStatusBarHidden(false, with: .slide)
    }

    open override var preferredStatusBarUpdateAnimation : UIStatusBarAnimation {
        return .slide
    }

    open override var prefersStatusBarHidden : Bool {
        return true
    }

    open override var shouldAutorotate : Bool {
        return false
    }

    open override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.portrait
    }

    // MARK: - API

    open func registerClass(_ cellClass: AnyClass?, forCellWithReuseIdentifier identifier: String) {
        collectionView.register(cellClass, forCellWithReuseIdentifier: identifier)
    }

    open func dequeuedReusableCellForClass<T : PhotoCollectionViewCell>(_ clazz: T.Type, indexPath: IndexPath, config: ((T) -> Void)) -> T {
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

    open func cellForpreviewAtIndexPath<T : PhotoCollectionViewCell>(_ indexPath: IndexPath) -> T? {
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
            self.collectionView.performBatchUpdates({
                handler()
                self.collectionView.deleteItems(at: [indexPath])
                }, completion: { finished in
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

    func flashButtonTapped(_ sender: UIButton) {
        let mode = captureManager.nextAvailableFlashMode() ?? .off
        captureManager.changeFlashMode(mode) {
            switch mode {
            case .off:
                self.flashButton.setTitle(NSLocalizedString("Off", comment:"flash off"), for: UIControlState())
            case .on:
                self.flashButton.setTitle(NSLocalizedString("On", comment:"flash on"), for: UIControlState())
            case .auto:
                self.flashButton.setTitle(NSLocalizedString("Auto", comment:"flash Auto"), for: UIControlState())
            }
        }
    }

    func presentImagePickerTapped(_ sender: AnyObject) {
        if libraryAuthorizationStatus() == .denied || libraryAuthorizationStatus() == .restricted {
            let error = NSError(domain: FinjinonLibraryAccessErrorDomain, code: 0, userInfo: nil)
            delegate?.photoCaptureViewController(self, didFailWithError: error)
            return
        }
        
        let controller = imagePickerAdapter.viewControllerForImageSelection({ assets in
            if let waitView = self.imagePickerWaitingForImageDataView, assets.count > 0 {
                waitView.translatesAutoresizingMaskIntoConstraints = false
                self.view.addSubview(waitView)
                
                waitView.removeConstraints(waitView.constraints.filter({ (constraint: NSLayoutConstraint) -> Bool in
                    return constraint.secondItem as! UIView == self.view
                }))
                self.view.addConstraint(NSLayoutConstraint(item: waitView, attribute: NSLayoutAttribute.centerX, relatedBy: NSLayoutRelation.equal, toItem: self.view, attribute: NSLayoutAttribute.centerX, multiplier: 1, constant: 0))
                self.view.addConstraint(NSLayoutConstraint(item: waitView, attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal, toItem: self.view, attribute: NSLayoutAttribute.centerY, multiplier: 1, constant: 0))
                
                switch UIDevice.current.orientation {
                case .landscapeRight:
                    self.view.addConstraint(NSLayoutConstraint(item: waitView, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: self.view, attribute: NSLayoutAttribute.width, multiplier: 1, constant: 0))
                    self.view.addConstraint(NSLayoutConstraint(item: waitView, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: self.view, attribute: NSLayoutAttribute.height, multiplier: 1, constant: 0))
                    
                case .landscapeLeft:
                    self.view.addConstraint(NSLayoutConstraint(item: waitView, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: self.view, attribute: NSLayoutAttribute.width, multiplier: 1, constant: 0))
                    self.view.addConstraint(NSLayoutConstraint(item: waitView, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: self.view, attribute: NSLayoutAttribute.height, multiplier: 1, constant: 0))
                    
                default:
                    self.view.addConstraint(NSLayoutConstraint(item: waitView, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: self.view, attribute: NSLayoutAttribute.height, multiplier: 1, constant: 0))
                    self.view.addConstraint(NSLayoutConstraint(item: waitView, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: self.view, attribute: NSLayoutAttribute.width, multiplier: 1, constant: 0))
                }
                waitView.rotateToCurrentDeviceOrientation()
            }
            
            let resolver = AssetResolver()
            var count = assets.count
            assets.forEach { asset in
                resolver.enqueueResolve(asset, completion: { image in
                    self.createAssetFromImage(image, completion: { (asset: Asset) in
                        self.didAddAsset(asset)
                        
                        count -= 1
                        if count == 0 {
                            self.imagePickerWaitingForImageDataView?.removeFromSuperview()
                        }
                    })
                })
            }
        }, completion: { cancelled in
            DispatchQueue.main.async {
                self.dismiss(animated: true, completion: nil)
            }
        })
        
        present(controller, animated: true, completion: nil)
    }

    func capturePhotoTapped(_ sender: UIButton) {
        sender.isEnabled = false
        UIView.animate(withDuration: 0.1, animations: { self.previewView.alpha = 0.0 }, completion: { finished in
            UIView.animate(withDuration: 0.1, animations: {self.previewView.alpha = 1.0})
        })

        captureManager.captureImage { (data, metadata) in
            sender.isEnabled = true

            self.createAssetFromImageData(data as Data, completion: self.didAddAsset)
        }
    }

    fileprivate func didAddAsset(_ asset: Asset) {
        DispatchQueue.main.async {
            self.collectionView.performBatchUpdates({
                self.delegate?.photoCaptureViewController(self, didAddAsset: asset)
                let insertedIndexPath: IndexPath
                if let count = self.delegate?.photoCaptureViewControllerNumberOfAssets(self) {
                    insertedIndexPath = IndexPath(item: count-1, section: 0)
                } else {
                    insertedIndexPath = IndexPath(item: 0, section: 0)
                }
                self.collectionView.insertItems(at: [insertedIndexPath])
            }, completion: { finished in
                self.scrollToLastAddedAssetAnimated(true)
            })
        }
    }

    fileprivate func scrollToLastAddedAssetAnimated(_ animated: Bool) {
        if let count = self.delegate?.photoCaptureViewControllerNumberOfAssets(self), count > 0 {
            self.collectionView.scrollToItem(at: IndexPath(item: count-1, section: 0), at: .left, animated: animated)
        }
    }

    func doneButtonTapped(_ sender: UIButton) {
        self.delegate?.photoCaptureViewControllerDidFinish(self)

        dismiss(animated: true, completion: nil)
    }

    func focusTapGestureRecognized(_ gestureRecognizer: UITapGestureRecognizer) {
        if gestureRecognizer.state == .ended {
            let point = gestureRecognizer.location(in: gestureRecognizer.view)

            focusIndicatorView.center = point
            UIView.animate(withDuration: 0.3, delay: 0.0, options: .beginFromCurrentState, animations: {
                self.focusIndicatorView.alpha = 1.0
                }, completion: { finished in
                    UIView.animate(withDuration: 0.2, delay: 1.6, options: .beginFromCurrentState, animations: {
                        self.focusIndicatorView.alpha = 0.0
                        }, completion: nil)
            })

            captureManager.lockFocusAtPointOfInterest(point)
        }
    }

    // MARK: - PhotoCollectionViewLayoutDelegate

    open func photoCollectionViewLayout(_ layout: UICollectionViewLayout, canMoveItemAtIndexPath indexPath: IndexPath) -> Bool {
        return delegate?.photoCaptureViewController(self, canMoveItemAtIndexPath: indexPath) ?? true
    }

    // MARK: - Private methods

    fileprivate func roundifyButton(_ button: UIButton, inset: CGFloat = 16) {
        button.tintColor = UIColor.white

        button.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        button.layer.borderColor = button.tintColor!.cgColor
        button.layer.borderWidth = 1.0
        button.layer.cornerRadius = button.bounds.height/2

        var insets = button.imageEdgeInsets
        insets.left -= inset
        button.imageEdgeInsets = insets
    }

    fileprivate func updateWidgetsToOrientation() {
        var flashPosition = flashButton.frame.origin
        var pickerPosition = pickerButton.frame.origin
        if orientation == .landscapeLeft || orientation == .landscapeRight {
            flashPosition = CGPoint(x: buttonMargin - (buttonMargin/3), y: buttonMargin)
            pickerPosition = CGPoint(x: view.bounds.width - (pickerButton.bounds.size.width/2 - buttonMargin), y: buttonMargin)
        } else if orientation == .portrait || orientation == .portraitUpsideDown {
            pickerPosition = CGPoint(x: view.bounds.width - (pickerButton.bounds.size.width + buttonMargin), y: buttonMargin)
            flashPosition = CGPoint(x: buttonMargin, y: buttonMargin)
        }
        let animations = {
            self.pickerButton.rotateToCurrentDeviceOrientation()
            self.pickerButton.frame.origin = pickerPosition
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
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
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
            self.deleteAssetAtIndex(indexPath.item, handler: {
                self.delegate?.photoCaptureViewController(self, deleteAssetAtIndexPath: indexPath)
            })
        }
    }
}


extension PhotoCaptureViewController: UICollectionViewDelegate {
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.photoCaptureViewController(self, didSelectAssetAtIndexPath: indexPath)
    }
}


extension UIView {
    public func rotateToCurrentDeviceOrientation() {
        self.rotateToDeviceOrientation(UIDevice.current.orientation)
    }

    public func rotateToDeviceOrientation(_ orientation: UIDeviceOrientation) {
        switch orientation {
        case .faceDown, .faceUp, .unknown:
            ()
        case .landscapeLeft:
            self.transform = CGAffineTransform(rotationAngle: CGFloat(Double.pi/2))
        case .landscapeRight:
            self.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi/2))
        case .portrait, .portraitUpsideDown:
            self.transform = CGAffineTransform(rotationAngle: 0)
        }
    }
}
