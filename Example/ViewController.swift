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
        let controller = PhotoCaptureViewController()
        controller.delegate = self
        controller.addInitialImages(self.images)
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
    func photoCaptureViewController(controller: PhotoCaptureViewController, didFinishEditingAssets assets: [Asset]) {
        NSLog("didFinishEditingAssets: \(assets)")
        self.images.removeAll(keepCapacity: false)
        for asset in assets {
            asset.retrieveImageWithWidth(100) { image in
                self.images.insert(image, atIndex: 0)
                self.tableView.reloadData()
            }
        }
    }

    func photoCaptureViewController(controller: PhotoCaptureViewController, didSelectAsset asset: Asset) {
        NSLog("did select asset \(asset)")
    }

    func photoCaptureViewController(controller: PhotoCaptureViewController, didFailWithError error: NSError) {
        NSLog("photoCaptureViewController:didFailWithError: \(error)")
    }
}
