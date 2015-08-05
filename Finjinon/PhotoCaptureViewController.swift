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
}

public class PhotoCaptureViewController: UIViewController {
    public weak var delegate: PhotoCaptureViewControllerDelegate?
    public var imagePickerAdapter: ImagePickerAdapter = ImagePickerControllerAdapter()

    private let storage = PhotoStorage()
    private let captureManager = CaptureManager()
    private var previewView: UIView!
    private var captureButton: TriggerButton!
    private let collectionView = UICollectionView(frame: CGRect.zeroRect, collectionViewLayout: UICollectionViewFlowLayout())
    private var containerView: UIView!
    private var focusIndicatorView: UIView!
    private var flashButton: UIButton!

    deinit {
        captureManager.stop(nil)
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.blackColor()

        // TODO: Move all the boring view setup to a storyboard/xib

        previewView = UIView(frame: view.bounds)
        previewView.autoresizingMask = .FlexibleWidth | .FlexibleHeight
        view.addSubview(previewView)
        let previewLayer = captureManager.previewLayer
        previewLayer.frame = previewView.layer.bounds
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

        let collectionViewHeight: CGFloat = 102

        let containerFrame = CGRect(x: 0, y: view.frame.height-76-collectionViewHeight, width: view.frame.width, height: 76+collectionViewHeight)

        var containerContentView : UIView!
        let isPreOS8 = floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1
        if (isPreOS8){
            containerView = UIView(frame: containerFrame)
            containerView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.8)
            containerContentView = containerView
        } else {
            containerView = UIVisualEffectView(effect: UIBlurEffect(style: .Dark))
            if let containerView = containerView as? UIVisualEffectView {
                containerContentView = containerView.contentView
            }
        }
        containerView.frame = containerFrame
        view.addSubview(containerView)

        collectionView.frame = CGRect(x: 0, y: 0, width: containerView.bounds.width, height: collectionViewHeight)
        let layout = PhotoCollectionViewLayout()
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
        containerContentView.addSubview(collectionView)
        collectionView.registerClass(PhotoCollectionViewCell.self, forCellWithReuseIdentifier: "PhotoCell")
        collectionView.dataSource = self
        collectionView.delegate = self

        captureButton = TriggerButton(frame: CGRect(x: (containerView.frame.width/2)-33, y: containerView.frame.height - 66 - 4, width: 66, height: 66))
        captureButton.layer.cornerRadius = 33
        captureButton.addTarget(self, action: Selector("capturePhotoTapped:"), forControlEvents: .TouchUpInside)
        containerContentView.addSubview(captureButton)
        captureButton.enabled = false

        let closeButton = UIButton(frame: CGRect(x: captureButton.frame.maxX, y: captureButton.frame.midY - 22, width: view.bounds.width - captureButton.frame.maxX, height: 44))
        closeButton.addTarget(self, action: Selector("doneButtonTapped:"), forControlEvents: .TouchUpInside)
        closeButton.setTitle(NSLocalizedString("Done", comment: ""), forState: .Normal)
        closeButton.tintColor = UIColor.whiteColor()
        containerContentView.addSubview(closeButton)

        let pickerButtonWidth: CGFloat = 114
        let pickerButton = UIButton(frame: CGRect(x: view.bounds.width - pickerButtonWidth - 12, y: 12, width: pickerButtonWidth, height: 38))
        pickerButton.setTitle(NSLocalizedString("Photos", comment: "Select from Photos buttont itle"), forState: .Normal)
        pickerButton.setImage(UIImage(named: "PhotosIcon"), forState: .Normal)
        pickerButton.addTarget(self, action: Selector("presentImagePickerTapped:"), forControlEvents: .TouchUpInside)
        pickerButton.titleLabel?.font = UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote)
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

    public override func supportedInterfaceOrientations() -> Int {
        return Int(UIInterfaceOrientationMask.Portrait.rawValue)
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
        if let selection = collectionView.indexPathsForSelectedItems() as? [NSIndexPath] {
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
        return CGRect.zeroRect
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

    // MARK: - Private methods

    func roundifyButton(button: UIButton, inset: CGFloat = 16) {
        button.tintColor = UIColor.whiteColor()

        button.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.3)
        button.layer.borderColor = button.tintColor!.CGColor
        button.layer.borderWidth = 1.0
        button.layer.cornerRadius = button.bounds.height/2

        var insets = button.imageEdgeInsets
        insets.left -= inset
        button.imageEdgeInsets = insets
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
