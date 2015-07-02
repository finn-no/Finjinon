//
//  ViewController.swift
//  Finjinon
//
//  Created by johsoren on 06/04/2015.
//  Copyright (c) 06/04/2015 johsoren. All rights reserved.
//

import UIKit

class ViewController: UITableViewController {
    var assets: [Asset] = []
    let captureController = PhotoCaptureViewController()

    override func viewDidLoad() {
        super.viewDidLoad()

        captureController.delegate = self

        for i in 0..<6 {
            self.captureController.createAssetFromImage(UIImage(named: "hoff.jpeg")!) { asset in
                self.assets.append(asset)
                self.tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: i, inSection: 0)], withRowAnimation: .Automatic)
            }
        }
    }

    @IBAction func addPhotosTapped(sender: AnyObject) {
        presentViewController(captureController, animated: true, completion: nil)
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return assets.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("ItemCell", forIndexPath: indexPath) as! UITableViewCell
        let asset = assets[indexPath.row]
        cell.textLabel?.text = asset.UUID
        cell.imageView?.image = nil
        asset.imageWithWidth(64, result: { image in
            cell.imageView?.image = image
            cell.setNeedsLayout()
        })

        return cell
    }
}


extension ViewController: PhotoCaptureViewControllerDelegate {
    func photoCaptureViewControllerDidFinish(controller: PhotoCaptureViewController, cellForItemAtIndexPath indexPath: NSIndexPath) -> PhotoCollectionViewCell? {
        let cell = controller.dequeueReusableCellWithReuseIdentifier(PhotoCollectionViewCell.cellIdentifier, forIndexPath: indexPath)

        let asset = assets[indexPath.item]
        // Set a thumbnail form the source image, or add your own network fetch code etc
        if let assetURL = asset.imageURL {

        } else {
            asset.imageWithWidth(cell.imageView.bounds.width) { image in
                cell.imageView.image = image
            }
        }

        return cell
    }

    func photoCaptureViewControllerDidFinish(controller: PhotoCaptureViewController) {

    }

    func photoCaptureViewController(controller: PhotoCaptureViewController, didSelectAssetAtIndexPath indexPath: NSIndexPath) {
        NSLog("tapped in \(indexPath.row)")
    }

    func photoCaptureViewController(controller: PhotoCaptureViewController, didFailWithError error: NSError) {
        NSLog("failure: \(error)")
    }

    func photoCaptureViewController(controller: PhotoCaptureViewController, didMoveItemFromIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {
        NSLog("moved from #\(fromIndexPath.item) to #\(toIndexPath.item)")
        tableView.moveRowAtIndexPath(fromIndexPath, toIndexPath: toIndexPath)
    }

    func photoCaptureViewControllerNumberOfAssets(controller: PhotoCaptureViewController) -> Int {
        return assets.count
    }

    func photoCaptureViewController(controller: PhotoCaptureViewController, assetForIndexPath indexPath: NSIndexPath) -> Asset {
        return assets[indexPath.item]
    }

    func photoCaptureViewController(controller: PhotoCaptureViewController, didAddAsset asset: Asset) {
        assets.insert(asset, atIndex: 0)
        tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: 0, inSection: 0)], withRowAnimation: .Automatic)
    }

    func photoCaptureViewController(controller: PhotoCaptureViewController, deleteAssetAtIndexPath indexPath: NSIndexPath) {
        assets.removeAtIndex(indexPath.item)
        tableView.deleteRowsAtIndexPaths([NSIndexPath(forRow: 0, inSection: 0)], withRowAnimation: .Automatic)
    }}
