//
//  PhotoCaptureViewController.swift
//  Finjinon
//
//  Created by Sørensen, Johan on 05.06.15.
//  Copyright (c) 2015 FINN.no AS. All rights reserved.
//

import UIKit
import AVFoundation

public class PhotoCaptureViewController: UIViewController {
    private(set) public var assets: [Asset] = [] {
        didSet {
            self.collectionView.reloadData() // TODO: insert item with animation
        }
    }
    public var completionHandler: ([Asset] -> Void)?

    private let cache = PhotoDiskCache()
    private let captureManager = CaptureManager()
    private var previewView: UIView!
    private var captureButton: TriggerButton!
    private var collectionView: UICollectionView!
    private var containerView: UIVisualEffectView!

    convenience init(completion: ([Asset] -> Void)?) {
        self.init()
        self.completionHandler = completion
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.blackColor()

        previewView = UIView(frame: view.bounds)
        previewView.autoresizingMask = .FlexibleWidth | .FlexibleHeight
        view.addSubview(previewView)
        let previewLayer = captureManager.previewLayer
        previewLayer.frame = previewView.layer.bounds
        previewView.layer.addSublayer(previewLayer)

        let collectionViewHeight: CGFloat = 102

        containerView = UIVisualEffectView(effect: UIBlurEffect(style: .Dark))
        containerView.frame = CGRect(x: 0, y: view.frame.height-76-collectionViewHeight, width: view.frame.width, height: 76+collectionViewHeight)
        view.addSubview(containerView)

        let layout = UICollectionViewFlowLayout()
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

        captureManager.prepare {
            NSLog("CaptureManager fully initialized")

            self.captureButton.enabled = true
        }
    }

    // MARK: - API

    // Add the initial set of images asynchronously
    public func addInitialImages(images: [UIImage]) {
        for image in images {
            cache.createAssetFromImage(image) { asset in
                self.assets.append(asset)
            }
        }
    }

    // MARK: - Actions

    func capturePhotoTapped(sender: UIButton) {
        sender.enabled = false
        captureManager.captureImage { (image, metadata) in
            sender.enabled = true
            NSLog("captured image: \(image)")
            // TODO: shutter effect
            self.cache.createAssetFromImage(image) { asset in
                self.assets.insert(asset, atIndex: 0)
            }
        }
    }

    func doneButtonTapped(sender: UIButton) {
        completionHandler?(assets)
        dismissViewControllerAnimated(true, completion: nil)
    }

    // MARK: - UIViewController

    public override func shouldAutorotate() -> Bool {
        return false
    }

    public override func supportedInterfaceOrientations() -> Int {
        return UIInterfaceOrientation.Portrait.rawValue
    }
}


extension PhotoCaptureViewController: UICollectionViewDataSource {
    public func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return assets.count
    }

    public func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("PhotoCell", forIndexPath: indexPath) as! PhotoCollectionViewCell
        let asset = assets[indexPath.row]
        cache.thumbnailForAsset(asset, forWidth: cell.imageView.bounds.width) { image in
            cell.imageView.image = image
        }
        return cell
    }
}


private class PhotoCollectionViewCell: UICollectionViewCell {
    let imageView = UIImageView(frame: CGRect.zeroRect)

    override init(frame: CGRect) {
        super.init(frame: frame)

        imageView.frame = bounds
        imageView.autoresizingMask = .FlexibleWidth | .FlexibleHeight
        contentView.addSubview(imageView)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
