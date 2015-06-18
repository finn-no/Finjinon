//
//  PhotoCaptureViewController.swift
//  Finjinon
//
//  Created by Sørensen, Johan on 05.06.15.
//  Copyright (c) 2015 FINN.no AS. All rights reserved.
//

import UIKit
import AVFoundation

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

public class PhotoCaptureViewController: UIViewController {
    private(set) public var images: [UIImage] = [] {
        didSet {
            self.collectionView.reloadData() // TODO: insert item with animation
        }
    }

    private let captureManager = CaptureManager()
    private var previewView: UIView!
    private var captureButton: TriggerButton!
    private var collectionView: UICollectionView!

    override public func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.blackColor()

        captureButton = TriggerButton(frame: CGRect(x: (view.frame.width/2)-33, y: view.frame.height-66-10 , width: 66, height: 66))
        captureButton.layer.cornerRadius = 33
        captureButton.addTarget(self, action: Selector("capturePhotoTapped:"), forControlEvents: .TouchUpInside)
        view.addSubview(captureButton)
        captureButton.enabled = false

        let closeButton = UIButton(frame: CGRect(x: 0, y: captureButton.frame.midY - 22, width: captureButton.frame.minX, height: 44))
        closeButton.addTarget(self, action: Selector("cancelButtonTapped:"), forControlEvents: .TouchUpInside)
        closeButton.setTitle(NSLocalizedString("Cancel", comment: ""), forState: .Normal)
        closeButton.tintColor = UIColor.whiteColor()
        view.addSubview(closeButton)

        previewView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: captureButton.frame.minY - 10))
        view.addSubview(previewView)
        let previewLayer = captureManager.previewLayer
        previewLayer.frame = previewView.bounds
        previewView.layer.addSublayer(previewLayer)

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .Horizontal
        collectionView = UICollectionView(frame: CGRect(x: 0, y: captureButton.frame.minY - (128+8), width: view.bounds.width, height: 128), collectionViewLayout: layout)
        let pad = layout.minimumInteritemSpacing + layout.minimumLineSpacing
        layout.itemSize = CGSize(width: collectionView.frame.height - pad, height: collectionView.frame.height - pad)
        collectionView.layer.borderColor = UIColor.orangeColor().CGColor
        collectionView.layer.borderWidth = 1.0
        collectionView.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.7)
        view.addSubview(collectionView)
        collectionView.registerClass(PhotoCollectionViewCell.self, forCellWithReuseIdentifier: "PhotoCell")
        collectionView.dataSource = self

        captureManager.prepare {
            NSLog("CaptureManager fully initialized")

            self.captureButton.enabled = true
        }
    }

    func capturePhotoTapped(sender: UIButton) {
        sender.enabled = false
        captureManager.captureImage { (image, metadata) in
            sender.enabled = true
            NSLog("captured image: \(image)")
            // TODO: shutter effect
            self.images.insert(image, atIndex: 0)
        }
    }

    func cancelButtonTapped(sender: UIButton) {
        dismissViewControllerAnimated(true, completion: nil)
    }
}


extension PhotoCaptureViewController: UICollectionViewDataSource {
    public func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }

    public func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("PhotoCell", forIndexPath: indexPath) as! PhotoCollectionViewCell
        let image = images[indexPath.row]
        cell.imageView.image = image // TODO: resize on bg queue to cell size
        return cell
    }
}
