//
//  ViewController.swift
//  Finjinon
//
//  Created by johsoren on 06/04/2015.
//  Copyright (c) 06/04/2015 johsoren. All rights reserved.
//

import UIKit

class ViewController: UITableViewController {
    var images: [UIImage] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        images = (0..<6).map({ _ in UIImage(named: "hoff.jpeg")! })
    }

    @IBAction func addPhotosTapped(sender: AnyObject) {
        let controller = PhotoCaptureViewController(images: self.images)
        controller.delegate = self
        presentViewController(controller, animated: true, completion: nil)
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return images.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("ItemCell", forIndexPath: indexPath) as! UITableViewCell
        let image = images[indexPath.row]
        cell.imageView?.image = image
        cell.textLabel?.text = NSStringFromCGSize(image.size)

        return cell
    }
}


extension ViewController: PhotoCaptureViewControllerDelegate {
    func photoCaptureViewController(controller: PhotoCaptureViewController, customizeCell cell: PhotoCollectionViewCell, asset: Asset) {
        // Set a thumbnail form the source image, or add your own network fetch code etc
        if let assetURL = asset.imageURL {

        } else {
            asset.imageWithWidth(cell.imageView.bounds.width) { image in
                cell.imageView.image = image
            }
        }
    }

    func photoCaptureViewController(controller: PhotoCaptureViewController, didFinishEditingAssets assets: [Asset]) {
        NSLog("didFinishEditingAssets: \(assets)")
        self.images.removeAll(keepCapacity: false)
        for asset in assets {
            asset.imageWithWidth(100) { image in
                self.images.insert(image, atIndex: 0)
                self.tableView.reloadData()
            }
        }
    }

    func photoCaptureViewController(controller: PhotoCaptureViewController, didAddAsset asset: Asset) {
        NSLog("did ADD asset \(asset)")
    }

    func photoCaptureViewController(controller: PhotoCaptureViewController, didSelectAsset asset: Asset) {
        NSLog("did select asset \(asset)")
    }

    func photoCaptureViewController(controller: PhotoCaptureViewController, didFailWithError error: NSError) {
        if error.domain == FinjinonCameraAccessErrorDomain {
            let alert = UIAlertView(title: nil, message: error.localizedDescription, delegate: nil, cancelButtonTitle: NSLocalizedString("OK", comment: ""))
            alert.show()
        } else {
            NSLog("photoCaptureViewController:didFailWithError: \(error)")
        }
    }

    func photoCaptureViewController(controller: PhotoCaptureViewController, didMoveItemFromIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {
        NSLog("moved from #\(fromIndexPath.item) to #\(toIndexPath.item)")
    }
}
