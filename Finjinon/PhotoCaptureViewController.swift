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

public class PhotoCaptureViewController: UIViewController {
    private(set) public var assets: [Asset] = []
    public var completionHandler: ([Asset] -> Void)?

    override public var editing: Bool {
        didSet {
            updateEditingState()
        }
    }

    private let storage = PhotoStorage()
    private let captureManager = CaptureManager()
    private var previewView: UIView!
    private var captureButton: TriggerButton!
    private var collectionView: UICollectionView!
    private var containerView: UIVisualEffectView!
    private var focusIndicatorView: UIView!

    convenience init(completion: ([Asset] -> Void)?) {
        self.init()
        self.completionHandler = completion
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

        let tapper = UITapGestureRecognizer(target: self, action: Selector("focusTapGestureRecognized:"))
        previewView.addGestureRecognizer(tapper)

        let collectionViewHeight: CGFloat = 102

        containerView = UIVisualEffectView(effect: UIBlurEffect(style: .Dark))
        containerView.frame = CGRect(x: 0, y: view.frame.height-76-collectionViewHeight, width: view.frame.width, height: 76+collectionViewHeight)
        view.addSubview(containerView)

        let layout = PhotoCollectionViewLayout()
        collectionView = UICollectionView(frame: CGRect(x: 0, y: 0, width: containerView.bounds.width, height: collectionViewHeight), collectionViewLayout: layout)

        layout.scrollDirection = .Horizontal
        let inset: CGFloat = 8
        layout.itemSize = CGSize(width: collectionView.frame.height - (inset*2), height: collectionView.frame.height - (inset*2))
        layout.sectionInset = UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
        layout.minimumInteritemSpacing = inset
        layout.minimumLineSpacing = inset

        collectionView.backgroundColor = UIColor.clearColor()
        collectionView.alwaysBounceHorizontal = true
        containerView.contentView.addSubview(collectionView)
        collectionView.registerClass(PhotoCollectionViewCell.self, forCellWithReuseIdentifier: "PhotoCell")
        collectionView.dataSource = self

        captureButton = TriggerButton(frame: CGRect(x: (containerView.frame.width/2)-33, y: containerView.frame.height - 66 - 4, width: 66, height: 66))
        captureButton.layer.cornerRadius = 33
        captureButton.addTarget(self, action: Selector("capturePhotoTapped:"), forControlEvents: .TouchUpInside)
        containerView.contentView.addSubview(captureButton)
        captureButton.enabled = false

        let closeButton = UIButton(frame: CGRect(x: 0, y: captureButton.frame.midY - 22, width: captureButton.frame.minX, height: 44))
        closeButton.addTarget(self, action: Selector("doneButtonTapped:"), forControlEvents: .TouchUpInside)
        closeButton.setTitle(NSLocalizedString("Done", comment: ""), forState: .Normal)
        closeButton.tintColor = UIColor.whiteColor()
        containerView.contentView.addSubview(closeButton)

        let pickerButtonWidth = containerView.bounds.width - captureButton.frame.maxX
        let pickerButton = UIButton(frame: CGRect(x: captureButton.frame.maxX, y: captureButton.frame.midY - 22, width: pickerButtonWidth, height: 44))
        pickerButton.setTitle(NSLocalizedString("Add…", comment: ""), forState: .Normal)
        pickerButton.addTarget(self, action: Selector("presentImagePicker:"), forControlEvents: .TouchUpInside)
        containerView.contentView.addSubview(pickerButton)

        captureManager.prepare {
            self.captureButton.enabled = true
        }
    }

    // MARK: - API

    // Add the initial set of images asynchronously
    public func addInitialImages(images: [UIImage]) {
        for image in images {
            storage.createAssetFromImage(image) { asset in
                self.assets.append(asset)
                self.collectionView.reloadData()
            }
        }
    }

    // MARK: - Actions

    func capturePhotoTapped(sender: UIButton) {
        sender.enabled = false
        UIView.animateWithDuration(0.1, animations: { self.previewView.alpha = 0.0 }, completion: { finished in
            UIView.animateWithDuration(0.1, animations: {self.previewView.alpha = 1.0})
        })

        captureManager.captureImage { (data, metadata) in
            sender.enabled = true

            self.storage.createAssetFromImageData(data) { asset in
                self.collectionView.performBatchUpdates({
                    self.assets.insert(asset, atIndex: 0)
                    self.collectionView.insertItemsAtIndexPaths([NSIndexPath(forItem: 0, inSection: 0)])
                }, completion: nil)
            }
        }
    }

    func doneButtonTapped(sender: UIButton) {
        completionHandler?(assets)
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

    // MARK: - UIViewController

    public override func shouldAutorotate() -> Bool {
        return false
    }

    public override func supportedInterfaceOrientations() -> Int {
        return UIInterfaceOrientation.Portrait.rawValue
    }

    // MARK: - Private methods

    private func updateEditingState() {
        for cell in collectionView.visibleCells() as! [PhotoCollectionViewCell] {
            cell.jiggleAndShowDeleteIcon(self.editing)
        }
    }
}


extension PhotoCaptureViewController: UICollectionViewDataSource, PhotoCollectionViewCellDelegate {
    public func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return assets.count
    }

    public func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("PhotoCell", forIndexPath: indexPath) as! PhotoCollectionViewCell
        let asset = assets[indexPath.row]
        asset.retrieveImageWithWidth(cell.imageView.bounds.width) { image in
            cell.imageView.image = image
        }
        cell.delegate = self
        cell.jiggleAndShowDeleteIcon(editing)
        return cell
    }

    func collectionViewCellDidLongPress(cell: PhotoCollectionViewCell) {
        editing = !editing
    }

    func collectionViewCellDidTapDelete(cell: PhotoCollectionViewCell) {
        let indexPath = collectionView.indexPathForCell(cell)!
        collectionView.performBatchUpdates({
            self.assets.removeAtIndex(indexPath.row)
            self.collectionView.deleteItemsAtIndexPaths([indexPath])
        }, completion: nil)
    }
}


extension PhotoCaptureViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func presentImagePicker(sender: AnyObject) {
        // TODO: implement some kind of adapter so we can use other kinds of image pickers (like one that supports multiple selections)
        let picker = UIImagePickerController()
        picker.mediaTypes = [kUTTypeImage]
        picker.delegate = self
        presentViewController(picker, animated: true, completion: nil)
    }

    public func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [NSObject : AnyObject]) {
        let image = info[UIImagePickerControllerOriginalImage] as! UIImage
        self.storage.createAssetFromImage(image) { asset in
            self.collectionView.performBatchUpdates({
                self.assets.insert(asset, atIndex: 0)
                self.collectionView.insertItemsAtIndexPaths([NSIndexPath(forItem: 0, inSection: 0)])
                }, completion: nil)
        }
        dismissViewControllerAnimated(true, completion: nil)
    }

    public func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        dismissViewControllerAnimated(true, completion: nil)
    }
}


internal protocol PhotoCollectionViewCellDelegate: NSObjectProtocol {
    func collectionViewCellDidLongPress(cell: PhotoCollectionViewCell)
    func collectionViewCellDidTapDelete(cell: PhotoCollectionViewCell)
}


internal class PhotoCollectionViewCell: UICollectionViewCell {
    weak var delegate: PhotoCollectionViewCellDelegate?
    let imageView = UIImageView(frame: CGRect.zeroRect)
    let closeButton = CloseButton(frame: CGRect(x: 0, y: 0, width: 22, height: 22))

    override init(frame: CGRect) {
        super.init(frame: frame)

        imageView.frame = bounds
        imageView.autoresizingMask = .FlexibleWidth | .FlexibleHeight
        contentView.addSubview(imageView)

        closeButton.addTarget(self, action: Selector("closeButtonTapped:"), forControlEvents: .TouchUpInside)
        closeButton.hidden = true
        contentView.addSubview(closeButton)

        let presser = UILongPressGestureRecognizer(target: self, action: Selector("longTapGestureRecognized:"))
        self.contentView.addGestureRecognizer(presser)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    internal override func prepareForReuse() {
        super.prepareForReuse()

        delegate = nil
        self.imageView.layer.removeAnimationForKey("jiggle")
        self.imageView.frame = bounds
        self.closeButton.hidden = true
    }

    func jiggleAndShowDeleteIcon(editing: Bool) {
        if editing {
            closeButton.alpha = 0.0
            closeButton.hidden = false
            UIView.animateWithDuration(0.23, delay: 0, options: .BeginFromCurrentState, animations: {
                self.closeButton.alpha = 1.0
                let offset = self.closeButton.bounds.height/2
                self.imageView.frame.origin.x = offset
                self.imageView.frame.origin.y = offset
                self.imageView.frame.size.height -= offset*2
                self.imageView.frame.size.width -= offset*2
            }, completion: { finished in
                self.imageView.layer.addAnimation(self.buildJiggleAnimation(), forKey: "jiggle")
            })
        } else {
            self.imageView.layer.removeAnimationForKey("jiggle")
            UIView.animateWithDuration(0.23, delay: 0, options: .BeginFromCurrentState, animations: {
                self.imageView.frame = self.contentView.bounds
                self.closeButton.alpha = 0.0
                }, completion: { finished in
                    self.closeButton.hidden = true
            })
        }
    }

    func longTapGestureRecognized(recognizer: UILongPressGestureRecognizer) {
        if recognizer.state == .Began {
            delegate?.collectionViewCellDidLongPress(self)
        }
    }

    func closeButtonTapped(sender: UIButton) {
        delegate?.collectionViewCellDidTapDelete(self)
    }

    private func buildJiggleAnimation() -> CABasicAnimation {
        let animation  = CABasicAnimation(keyPath: "transform.rotation")
        let startAngle = (-2) * M_PI/180.0;
        animation.fromValue = startAngle
        animation.toValue = 3 * -startAngle
        animation.autoreverses = true
        animation.repeatCount = Float.infinity
        let duration = 0.16
        animation.duration = duration
        animation.timeOffset = Double((arc4random() % 100) / 100) - duration
        return animation
    }
}


internal class PhotoCollectionViewLayout: UICollectionViewFlowLayout {
    var insertedIndexPaths: [NSIndexPath] = []

    override func prepareForCollectionViewUpdates(updateItems: [AnyObject]!) {
        super.prepareForCollectionViewUpdates(updateItems)

        insertedIndexPaths.removeAll(keepCapacity: true)

        for update in updateItems as! [UICollectionViewUpdateItem] {
            switch update.updateAction {
            case .Insert:
                insertedIndexPaths.append(update.indexPathAfterUpdate!)
            default:
                return
            }
        }
    }

    override func initialLayoutAttributesForAppearingItemAtIndexPath(itemIndexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
        let attrs = super.initialLayoutAttributesForAppearingItemAtIndexPath(itemIndexPath)

        if contains(insertedIndexPaths, itemIndexPath) {
            if let attrs = attrs {
                let transform = CATransform3DTranslate(attrs.transform3D, attrs.frame.midX - self.collectionView!.frame.midX, attrs.frame.midY - self.collectionView!.frame.midY, 0)
                attrs.transform3D = CATransform3DScale(transform, 0.001, 0.001, 1)
            }
        }

        return attrs
    }
}
