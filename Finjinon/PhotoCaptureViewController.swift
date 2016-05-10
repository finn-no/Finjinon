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
    func photoCaptureViewControllerDidFinish(controller: PhotoCaptureViewController)
    func photoCaptureViewController(controller: PhotoCaptureViewController, didSelectAssetAtIndexPath indexPath: NSIndexPath)
    func photoCaptureViewController(controller: PhotoCaptureViewController, didFailWithError error: NSError)

    func photoCaptureViewController(controller: PhotoCaptureViewController, cellForItemAtIndexPath indexPath: NSIndexPath) -> PhotoCollectionViewCell?
    func photoCaptureViewController(controller: PhotoCaptureViewController, didMoveItemFromIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath)

    func photoCaptureViewControllerNumberOfAssets(controller: PhotoCaptureViewController) -> Int
    func photoCaptureViewController(controller: PhotoCaptureViewController, assetForIndexPath indexPath: NSIndexPath) -> Asset
    // delegate is responsible for updating own data structure to include new asset at the tip when one is added,
    // eg photoCaptureViewControllerNumberOfAssets should be +1 after didAddAsset is called
    func photoCaptureViewController(controller: PhotoCaptureViewController, didAddAsset asset: Asset)
    func photoCaptureViewController(controller: PhotoCaptureViewController, deleteAssetAtIndexPath indexPath: NSIndexPath)
    func photoCaptureViewController(controller: PhotoCaptureViewController, canMoveItemAtIndexPath indexPath: NSIndexPath) -> Bool
}

public class PhotoCaptureViewController: UIViewController, PhotoCollectionViewLayoutDelegate {
    public weak var delegate: PhotoCaptureViewControllerDelegate?
    public var imagePickerAdapter: ImagePickerAdapter = ImagePickerControllerAdapter()

    private let storage = PhotoStorage()
    private let captureManager = CaptureManager()
    private var previewView: UIView!
    private var captureButton: TriggerButton!
    private let collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout())
    private var containerView: UIView!
    private var focusIndicatorView: UIView!
    private var flashButton: UIButton!
    private var pickerButton : UIButton!
    private var closeButton : UIButton!
    private let buttonMargin : CGFloat = 12
    private var orientation : UIDeviceOrientation = .Portrait

    deinit {
        captureManager.stop(nil)
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.blackColor()

        // TODO: Move all the boring view setup to a storyboard/xib

        previewView = UIView(frame: view.bounds)
        previewView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        view.addSubview(previewView)
        let previewLayer = captureManager.previewLayer
        // We are using AVCaptureSessionPresetPhoto which has a 4:3 aspect ratio
        let viewFinderWidth = view.bounds.size.width
        var viewFinderHeight = (viewFinderWidth/3) * 4
        if captureManager.viewfinderMode == .FullScreen {
            viewFinderHeight = view.bounds.size.height
        }
        previewLayer.frame = CGRectMake(0, 0, viewFinderWidth, viewFinderHeight)
        previewView.layer.addSublayer(previewLayer)

        focusIndicatorView = UIView(frame: CGRect(x: 0, y: 0, width: 64, height: 64))
        focusIndicatorView.backgroundColor = UIColor.clearColor()
        focusIndicatorView.layer.borderColor = UIColor.orangeColor().CGColor
        focusIndicatorView.layer.borderWidth = 1.0
        focusIndicatorView.alpha = 0.0
        previewView.addSubview(focusIndicatorView)

        flashButton = UIButton(frame: CGRect(x: buttonMargin, y: buttonMargin, width: 70, height: 38))
        flashButton.setImage(UIImage(named: "LightningIcon"), forState: .Normal)
        flashButton.setTitle(NSLocalizedString("Off", comment:"flash off"), forState: .Normal)
        flashButton.addTarget(self, action: #selector(flashButtonTapped(_:)), forControlEvents: .TouchUpInside)
        flashButton.titleLabel?.font = UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote)
        flashButton.tintColor = UIColor.whiteColor()
        flashButton.layer.anchorPoint = CGPointMake(0.5, 0.5)
        roundifyButton(flashButton, inset: 14)

        let tapper = UITapGestureRecognizer(target: self, action: #selector(focusTapGestureRecognized(_:)))
        previewView.addGestureRecognizer(tapper)

        var collectionViewHeight: CGFloat = min(view.frame.size.height/6, 120)
        let collectionViewBottomMargin : CGFloat = 70
        let cameraButtonHeight : CGFloat = 66

        var containerFrame = CGRect(x: 0, y: view.frame.height-collectionViewBottomMargin-collectionViewHeight, width: view.frame.width, height: collectionViewBottomMargin+collectionViewHeight)
        if captureManager.viewfinderMode == .Window {
            let containerHeight = CGRectGetHeight(view.frame) - viewFinderHeight
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

        layout.scrollDirection = .Horizontal
        let inset: CGFloat = 8
        layout.itemSize = CGSize(width: collectionView.frame.height - (inset*2), height: collectionView.frame.height - (inset*2))
        layout.sectionInset = UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
        layout.minimumInteritemSpacing = inset
        layout.minimumLineSpacing = inset
        layout.didReorderHandler = { [weak self] (fromIndexPath, toIndexPath) in
            if let welf = self {
                welf.delegate?.photoCaptureViewController(welf, didMoveItemFromIndexPath: fromIndexPath, toIndexPath: toIndexPath)
            }
        }

        collectionView.backgroundColor = UIColor.clearColor()
        collectionView.alwaysBounceHorizontal = true
        containerView.addSubview(collectionView)
        collectionView.registerClass(PhotoCollectionViewCell.self, forCellWithReuseIdentifier: "PhotoCell")
        collectionView.dataSource = self
        collectionView.delegate = self

        captureButton = TriggerButton(frame: CGRect(x: (containerView.frame.width/2)-cameraButtonHeight/2, y: containerView.frame.height - cameraButtonHeight - 4, width: cameraButtonHeight, height: cameraButtonHeight))
        captureButton.layer.cornerRadius = cameraButtonHeight/2
        captureButton.addTarget(self, action: #selector(capturePhotoTapped(_:)), forControlEvents: .TouchUpInside)
        containerView.addSubview(captureButton)
        captureButton.enabled = false
        captureButton.accessibilityLabel = NSLocalizedString("Take a picture", comment: "")

        closeButton = UIButton(frame: CGRect(x: captureButton.frame.maxX, y: captureButton.frame.midY - 22, width: view.bounds.width - captureButton.frame.maxX, height: 44))
        closeButton.addTarget(self, action: #selector(doneButtonTapped(_:)), forControlEvents: .TouchUpInside)
        closeButton.setTitle(NSLocalizedString("Done", comment: ""), forState: .Normal)
        closeButton.tintColor = UIColor.whiteColor()
        closeButton.layer.anchorPoint = CGPointMake(0.5, 0.5)
        containerView.addSubview(closeButton)

        let pickerButtonWidth: CGFloat = 114
        pickerButton = UIButton(frame: CGRect(x: view.bounds.width - pickerButtonWidth - buttonMargin, y: buttonMargin, width: pickerButtonWidth, height: 38))
        pickerButton.setTitle(NSLocalizedString("Photos", comment: "Select from Photos buttont itle"), forState: .Normal)
        pickerButton.setImage(UIImage(named: "PhotosIcon"), forState: .Normal)
        pickerButton.addTarget(self, action: #selector(presentImagePickerTapped(_:)), forControlEvents: .TouchUpInside)
        pickerButton.titleLabel?.font = UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote)
        pickerButton.autoresizingMask = [.FlexibleTopMargin]
        pickerButton.layer.anchorPoint = CGPointMake(0.5, 0.5)
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

            UIView.animateWithDuration(0.2) {
                self.captureButton.enabled = true
                self.previewView.alpha = 1.0
            }
        }

        NSNotificationCenter.defaultCenter().addObserverForName(UIDeviceOrientationDidChangeNotification, object: nil, queue: nil) { (NSNotification) -> Void in
            switch UIDevice.currentDevice().orientation {
            case .FaceDown, .FaceUp, .Unknown:
                ()
            case .LandscapeLeft, .LandscapeRight, .Portrait, .PortraitUpsideDown:
                self.orientation = UIDevice.currentDevice().orientation
                self.updateWidgetsToOrientation()
            }
        }
    }

    public override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        collectionView.reloadData()

        scrollToLastAddedAssetAnimated(false)

        // In case the application uses the old style for managing status bar appearance
        UIApplication.sharedApplication().setStatusBarHidden(true, withAnimation: .Slide)
    }

    public override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)

        UIApplication.sharedApplication().setStatusBarHidden(false, withAnimation: .Slide)
    }

    public override func preferredStatusBarUpdateAnimation() -> UIStatusBarAnimation {
        return .Slide
    }

    public override func prefersStatusBarHidden() -> Bool {
        return true
    }

    public override func shouldAutorotate() -> Bool {
        return false
    }

    public override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.Portrait
    }

    // MARK: - API

    public func registerClass(cellClass: AnyClass?, forCellWithReuseIdentifier identifier: String) {
        collectionView.registerClass(cellClass, forCellWithReuseIdentifier: identifier)
    }

    public func dequeuedReusableCellForClass<T : PhotoCollectionViewCell>(clazz: T.Type, indexPath: NSIndexPath, config: (T -> Void)) -> T {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(clazz.cellIdentifier(), forIndexPath: indexPath) as! T
        config(cell)
        return cell
    }

    public func reloadPreviewItemsAtIndexes(indexes: [Int]) {
        let indexPaths = indexes.map { NSIndexPath(forItem: $0, inSection: 0) }
        collectionView.reloadItemsAtIndexPaths(indexPaths)
    }

    public func reloadPreviews() {
        collectionView.reloadData()
    }

    public func selectedPreviewIndexPath() -> NSIndexPath? {
        if let selection = collectionView.indexPathsForSelectedItems() {
            return selection.first
        }

        return nil
    }

    public func cellForpreviewAtIndexPath<T : PhotoCollectionViewCell>(indexPath: NSIndexPath) -> T? {
        return collectionView.cellForItemAtIndexPath(indexPath) as? T
    }

    /// returns the rect in view (minus the scroll offset) of the thumbnail at the given indexPath.
    /// Useful for presenting sheets etc from the thumbnail
    public func previewRectForIndexPath(indexPath: NSIndexPath) -> CGRect {
        if let attributes = collectionView.layoutAttributesForItemAtIndexPath(indexPath) {
            var rect = attributes.frame
            rect.origin.x -= collectionView.contentOffset.x
            rect.origin.y -= collectionView.contentOffset.y
            return view.convertRect(rect, fromView: collectionView.superview)
        }
        return CGRect.zero
    }

    public func createAssetFromImageData(data: NSData, completion: Asset -> Void) {
        storage.createAssetFromImageData(data, completion: completion)
    }

    public func createAssetFromImage(image: UIImage, completion: Asset -> Void) {
        storage.createAssetFromImage(image, completion: completion)
    }

    public func createAssetFromImageURL(imageURL: NSURL, dimensions: CGSize, completion: Asset -> Void) {
        storage.createAssetFromImageURL(imageURL, dimensions: dimensions, completion: completion)
    }

    /// Deletes item at the given index. Perform any deletions from datamodel in the handler
    public func deleteAssetAtIndex(idx: Int, handler: () -> Void) {
        let indexPath = NSIndexPath(forItem: idx, inSection: 0)
        if let asset = delegate?.photoCaptureViewController(self, assetForIndexPath: indexPath) {
            self.collectionView.performBatchUpdates({
                handler()
                self.collectionView.deleteItemsAtIndexPaths([indexPath])
                }, completion: { finished in
                    if asset.imageURL == nil {
                        self.storage.deleteAsset(asset, completion: {})
                    }
            })
        }
    }

    public func libraryAuthorizationStatus() -> PHAuthorizationStatus {
        return PHPhotoLibrary.authorizationStatus()
    }

    public func cameraAuthorizationStatus() -> AVAuthorizationStatus {
        return captureManager.authorizationStatus()
    }

    // MARK: - Actions

    func flashButtonTapped(sender: UIButton) {
        let mode = captureManager.nextAvailableFlashMode() ?? .Off
        captureManager.changeFlashMode(mode) {
            switch mode {
            case .Off:
                self.flashButton.setTitle(NSLocalizedString("Off", comment:"flash off"), forState: .Normal)
            case .On:
                self.flashButton.setTitle(NSLocalizedString("On", comment:"flash on"), forState: .Normal)
            case .Auto:
                self.flashButton.setTitle(NSLocalizedString("Auto", comment:"flash Auto"), forState: .Normal)
            }
        }
    }

    func presentImagePickerTapped(sender: AnyObject) {
        if libraryAuthorizationStatus() == .Denied || libraryAuthorizationStatus() == .Restricted {
            let error = NSError(domain: FinjinonLibraryAccessErrorDomain, code: 0, userInfo: nil)
            delegate?.photoCaptureViewController(self, didFailWithError: error)
            return
        }

        let controller = imagePickerAdapter.viewControllerForImageSelection({ assets in
            let resolver = AssetResolver()
            assets.forEach { asset in
                resolver.enqueueResolve(asset, completion: { image in
                    self.createAssetFromImage(image, completion: self.didAddAsset)
                })
            }
        }, completion: { cancelled in
            dispatch_async(dispatch_get_main_queue()) {
                self.dismissViewControllerAnimated(true, completion: nil)
            }
        })

        presentViewController(controller, animated: true, completion: nil)
    }

    func capturePhotoTapped(sender: UIButton) {
        sender.enabled = false
        UIView.animateWithDuration(0.1, animations: { self.previewView.alpha = 0.0 }, completion: { finished in
            UIView.animateWithDuration(0.1, animations: {self.previewView.alpha = 1.0})
        })

        captureManager.captureImage { (data, metadata) in
            sender.enabled = true

            self.createAssetFromImageData(data, completion: self.didAddAsset)
        }
    }

    private func didAddAsset(asset: Asset) {
        dispatch_async(dispatch_get_main_queue()) {
            self.collectionView.performBatchUpdates({
                self.delegate?.photoCaptureViewController(self, didAddAsset: asset)
                let insertedIndexPath: NSIndexPath
                if let count = self.delegate?.photoCaptureViewControllerNumberOfAssets(self) {
                    insertedIndexPath = NSIndexPath(forItem: count-1, inSection: 0)
                } else {
                    insertedIndexPath = NSIndexPath(forItem: 0, inSection: 0)
                }
                self.collectionView.insertItemsAtIndexPaths([insertedIndexPath])
            }, completion: { finished in
                self.scrollToLastAddedAssetAnimated(true)
            })
        }
    }

    private func scrollToLastAddedAssetAnimated(animated: Bool) {
        if let count = self.delegate?.photoCaptureViewControllerNumberOfAssets(self) where count > 0 {
            self.collectionView.scrollToItemAtIndexPath(NSIndexPath(forItem: count-1, inSection: 0), atScrollPosition: .Left, animated: animated)
        }
    }

    func doneButtonTapped(sender: UIButton) {
        self.delegate?.photoCaptureViewControllerDidFinish(self)

        dismissViewControllerAnimated(true, completion: nil)
    }

    func focusTapGestureRecognized(gestureRecognizer: UITapGestureRecognizer) {
        if gestureRecognizer.state == .Ended {
            let point = gestureRecognizer.locationInView(gestureRecognizer.view)

            focusIndicatorView.center = point
            UIView.animateWithDuration(0.3, delay: 0.0, options: .BeginFromCurrentState, animations: {
                self.focusIndicatorView.alpha = 1.0
                }, completion: { finished in
                    UIView.animateWithDuration(0.2, delay: 1.6, options: .BeginFromCurrentState, animations: {
                        self.focusIndicatorView.alpha = 0.0
                        }, completion: nil)
            })

            captureManager.lockFocusAtPointOfInterest(point)
        }
    }

    // MARK: - PhotoCollectionViewLayoutDelegate

    public func photoCollectionViewLayout(layout: UICollectionViewLayout, canMoveItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        return delegate?.photoCaptureViewController(self, canMoveItemAtIndexPath: indexPath) ?? true
    }

    // MARK: - Private methods

    private func roundifyButton(button: UIButton, inset: CGFloat = 16) {
        button.tintColor = UIColor.whiteColor()

        button.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.3)
        button.layer.borderColor = button.tintColor!.CGColor
        button.layer.borderWidth = 1.0
        button.layer.cornerRadius = button.bounds.height/2

        var insets = button.imageEdgeInsets
        insets.left -= inset
        button.imageEdgeInsets = insets
    }

    private func updateWidgetsToOrientation() {
        var flashPosition = flashButton.frame.origin
        var pickerPosition = pickerButton.frame.origin
        if orientation == .LandscapeLeft || orientation == .LandscapeRight {
            flashPosition = CGPointMake(buttonMargin - (buttonMargin/3), buttonMargin)
            pickerPosition = CGPointMake(view.bounds.width - (pickerButton.bounds.size.width/2 - buttonMargin), buttonMargin)
        } else if orientation == .Portrait || orientation == .PortraitUpsideDown {
            pickerPosition = CGPointMake(view.bounds.width - (pickerButton.bounds.size.width + buttonMargin), buttonMargin)
            flashPosition = CGPointMake(buttonMargin, buttonMargin)
        }
        let animations = {
            self.pickerButton.rotateToCurrentDeviceOrientation()
            self.pickerButton.frame.origin = pickerPosition
            self.flashButton.rotateToCurrentDeviceOrientation()
            self.flashButton.frame.origin = flashPosition
            self.closeButton.rotateToCurrentDeviceOrientation()

            for cell in self.collectionView.visibleCells() {
                cell.contentView.rotateToCurrentDeviceOrientation()
            }
        }
        UIView.animateWithDuration(0.25, animations: animations)
    }
}


extension PhotoCaptureViewController: UICollectionViewDataSource, PhotoCollectionViewCellDelegate {
    public func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return delegate?.photoCaptureViewControllerNumberOfAssets(self) ?? 0
    }

    public func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell: PhotoCollectionViewCell
        if let delegateCell = delegate?.photoCaptureViewController(self, cellForItemAtIndexPath: indexPath) {
            cell = delegateCell
        } else {
            cell = collectionView.dequeueReusableCellWithReuseIdentifier(PhotoCollectionViewCell.cellIdentifier(), forIndexPath: indexPath) as! PhotoCollectionViewCell
        }
        // This cannot use the currentRotation call as it might be called when .FaceUp or .FaceDown is device-orientation
        cell.contentView.rotateToDeviceOrientation(orientation)
        cell.delegate = self
        return cell
    }

    func collectionViewCellDidTapDelete(cell: PhotoCollectionViewCell) {
        if let indexPath = collectionView.indexPathForCell(cell) {
            self.deleteAssetAtIndex(indexPath.item, handler: {
                self.delegate?.photoCaptureViewController(self, deleteAssetAtIndexPath: indexPath)
            })
        }
    }
}


extension PhotoCaptureViewController: UICollectionViewDelegate {
    public func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        delegate?.photoCaptureViewController(self, didSelectAssetAtIndexPath: indexPath)
    }
}


extension UIView {
    public func rotateToCurrentDeviceOrientation() {
        self.rotateToDeviceOrientation(UIDevice.currentDevice().orientation)
    }

    public func rotateToDeviceOrientation(orientation: UIDeviceOrientation) {
        switch orientation {
        case .FaceDown, .FaceUp, .Unknown:
            ()
        case .LandscapeLeft:
            self.transform = CGAffineTransformMakeRotation(CGFloat(M_PI/2))
        case .LandscapeRight:
            self.transform = CGAffineTransformMakeRotation(CGFloat(-M_PI/2))
        case .Portrait, .PortraitUpsideDown:
            self.transform = CGAffineTransformMakeRotation(0)
        }
    }
}
