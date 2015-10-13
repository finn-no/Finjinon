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
import AssetsLibrary

let FinjinonCameraAccessErrorDomain = "FinjinonCameraAccessErrorDomain"
let FinjinonCameraAccessErrorDeniedCode = 1
let FinjinonCameraAccessErrorDeniedInitialRequestCode = 2
let FinjinonLibraryAccessErrorDomain = "FinjinonLibraryAccessErrorDomain"

public protocol PhotoCaptureViewControllerDelegate: NSObjectProtocol {
    func photoCaptureViewControllerDidFinish(controller: PhotoCaptureViewController, cellForItemAtIndexPath indexPath: NSIndexPath) -> PhotoCollectionViewCell?

    func photoCaptureViewControllerDidFinish(controller: PhotoCaptureViewController)
    func photoCaptureViewController(controller: PhotoCaptureViewController, didSelectAssetAtIndexPath indexPath: NSIndexPath)
    func photoCaptureViewController(controller: PhotoCaptureViewController, didFailWithError error: NSError)

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
    private var widgetOrientation : UIInterfaceOrientation = .Portrait
    private var deviceOrientation : UIDeviceOrientation = UIDevice.currentDevice().orientation {
        didSet {
            let interfaceCompatibleOrientation = deviceOrientation != .FaceUp || deviceOrientation != .FaceDown || deviceOrientation != .Unknown
            if interfaceCompatibleOrientation && widgetOrientation.rawValue != deviceOrientation.rawValue {
                let newOrientation = UIInterfaceOrientation(rawValue: deviceOrientation.rawValue)!
                updateWidgetsToOrientation(newOrientation)
            }
        }
    }
    private var pickerButton : UIButton!
    private var closeButton : UIButton!

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

        flashButton = UIButton(frame: CGRect(x: 12, y: 12, width: 70, height: 38))
        flashButton.setImage(UIImage(named: "LightningIcon"), forState: .Normal)
        flashButton.setTitle(NSLocalizedString("Off", comment:"flash off"), forState: .Normal)
        flashButton.addTarget(self, action: Selector("flashButtonTapped:"), forControlEvents: .TouchUpInside)
        flashButton.titleLabel?.font = UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote)
        flashButton.tintColor = UIColor.whiteColor()
        roundifyButton(flashButton, inset: 14)

        let tapper = UITapGestureRecognizer(target: self, action: Selector("focusTapGestureRecognized:"))
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
        captureButton.addTarget(self, action: Selector("capturePhotoTapped:"), forControlEvents: .TouchUpInside)
        containerView.addSubview(captureButton)
        captureButton.enabled = false
        captureButton.accessibilityLabel = NSLocalizedString("Take a picture", comment: "")

        closeButton = UIButton(frame: CGRect(x: captureButton.frame.maxX, y: captureButton.frame.midY - 22, width: view.bounds.width - captureButton.frame.maxX, height: 44))
        closeButton.addTarget(self, action: Selector("doneButtonTapped:"), forControlEvents: .TouchUpInside)
        closeButton.setTitle(NSLocalizedString("Done", comment: ""), forState: .Normal)
        closeButton.tintColor = UIColor.whiteColor()
        containerView.addSubview(closeButton)

        let pickerButtonWidth: CGFloat = 114
        pickerButton = UIButton(frame: CGRect(x: view.bounds.width - pickerButtonWidth - 12, y: 12, width: pickerButtonWidth, height: 38))
        pickerButton.setTitle(NSLocalizedString("Photos", comment: "Select from Photos buttont itle"), forState: .Normal)
        pickerButton.setImage(UIImage(named: "PhotosIcon"), forState: .Normal)
        pickerButton.addTarget(self, action: Selector("presentImagePickerTapped:"), forControlEvents: .TouchUpInside)
        pickerButton.titleLabel?.font = UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote)
        pickerButton.autoresizingMask = [.FlexibleTopMargin]
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
            self.deviceOrientation = UIDevice.currentDevice().orientation
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

    func registerClass(cellClass: AnyClass?, forCellWithReuseIdentifier identifier: String) {
        collectionView.registerClass(cellClass, forCellWithReuseIdentifier: identifier)
    }

    func dequeuedReusableCellForClass<T : PhotoCollectionViewCell>(clazz: T.Type, indexPath: NSIndexPath, config: (T -> Void)) -> T {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(clazz.cellIdentifier(), forIndexPath: indexPath) as! T
        config(cell)
        return cell
    }

    func reloadPreviewItemsAtIndexes(indexes: [Int]) {
        let indexPaths = indexes.map { NSIndexPath(forItem: $0, inSection: 0) }
        collectionView.reloadItemsAtIndexPaths(indexPaths)
    }

    func reloadPreviews() {
        collectionView.reloadData()
    }

    func selectedPreviewIndexPath() -> NSIndexPath? {
        if let selection = collectionView.indexPathsForSelectedItems() {
            return selection.first
        }

        return nil
    }

    func cellForpreviewAtIndexPath<T : PhotoCollectionViewCell>(indexPath: NSIndexPath) -> T? {
        return collectionView.cellForItemAtIndexPath(indexPath) as? T
    }

    /// returns the rect in view (minus the scroll offset) of the thumbnail at the given indexPath.
    /// Useful for presenting sheets etc from the thumbnail
    func previewRectForIndexPath(indexPath: NSIndexPath) -> CGRect {
        if let attributes = collectionView.layoutAttributesForItemAtIndexPath(indexPath) {
            var rect = attributes.frame
            rect.origin.x -= collectionView.contentOffset.x
            rect.origin.y -= collectionView.contentOffset.y
            return view.convertRect(rect, fromView: collectionView.superview)
        }
        return CGRect.zero
    }

    func createAssetFromImageData(data: NSData, completion: Asset -> Void) {
        storage.createAssetFromImageData(data, completion: completion)
    }

    func createAssetFromImage(image: UIImage, completion: Asset -> Void) {
        storage.createAssetFromImage(image, completion: completion)
    }

    func createAssetFromImageURL(imageURL: NSURL, dimensions: CGSize, completion: Asset -> Void) {
        storage.createAssetFromImageURL(imageURL, dimensions: dimensions, completion: completion)
    }

    /// Deletes item at the given index. Perform any deletions from datamodel in the handler
    func deleteAssetAtIndex(idx: Int, handler: () -> Void) {
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

    func libraryAuthorizationStatus() -> ALAuthorizationStatus {
        return ALAssetsLibrary.authorizationStatus()
    }

    func cameraAuthorizationStatus() -> AVAuthorizationStatus {
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

        let controller = imagePickerAdapter.viewControllerForImageSelection({ info in
            if let imageURL = info[UIImagePickerControllerMediaURL] as? NSURL, let data = NSData(contentsOfURL: imageURL) {
                self.createAssetFromImageData(data, completion: self.didAddAsset)
            } else if let assetURL = info[UIImagePickerControllerReferenceURL] as? NSURL {
                self.storage.createAssetFromAssetLibraryURL(assetURL, completion: self.didAddAsset)
            } else if let image = info[UIImagePickerControllerOriginalImage] as? UIImage {
                self.createAssetFromImage(image, completion: self.didAddAsset)
            }
            }, completion: { cancelled in
                self.dismissViewControllerAnimated(true, completion: nil)
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
        collectionView.performBatchUpdates({
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

    private func updateWidgetsToOrientation(orientation: UIInterfaceOrientation) {
        print(orientation.rawValue)
        closeButton.layer.anchorPoint = CGPointMake(0.5, 0.5)
        flashButton.layer.anchorPoint = CGPointMake(0.5, 0.5)
        pickerButton.layer.anchorPoint = CGPointMake(0.5, 0.5)

        var flashPosition = CGPointZero
        var pickerPosition = CGPointZero

        var radians : CGFloat {
            switch orientation {
            case .LandscapeLeft:
                pickerPosition = CGPointMake(view.bounds.width - 45, 12) // 45 = width/2 - margin
                flashPosition = CGPointMake(8, 12)
                return CGFloat(-M_PI/2)
            case .LandscapeRight:
                pickerPosition = CGPointMake(view.bounds.width - 45, 12) // 45 = width/2 - margin
                flashPosition = CGPointMake(8, 12)
                return CGFloat(M_PI/2)
            default:
                pickerPosition = CGPointMake(view.bounds.width - 126, 12) // 126 = 114 + 12 (width + margin)?
                flashPosition = CGPointMake(12, 12)
                return 0
            }
        }
        let animations = {
            let rotation = CGAffineTransformMakeRotation(radians)
            self.pickerButton.transform = rotation
            self.pickerButton.frame.origin = pickerPosition

            self.flashButton.transform = rotation
            self.flashButton.frame.origin = flashPosition

            self.closeButton.transform = rotation
        }
        UIView.animateWithDuration(0.25, animations: animations)
        widgetOrientation = orientation
    }
}


extension PhotoCaptureViewController: UICollectionViewDataSource, PhotoCollectionViewCellDelegate {
    public func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return delegate?.photoCaptureViewControllerNumberOfAssets(self) ?? 0
    }

    public func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell: PhotoCollectionViewCell
        if let delegateCell = delegate?.photoCaptureViewControllerDidFinish(self, cellForItemAtIndexPath: indexPath) {
            cell = delegateCell
        } else {
            cell = collectionView.dequeueReusableCellWithReuseIdentifier(PhotoCollectionViewCell.cellIdentifier(), forIndexPath: indexPath) as! PhotoCollectionViewCell
        }

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
