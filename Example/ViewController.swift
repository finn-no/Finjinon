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

        images = [UIImage(named: "hoff.jpeg")!]
    }

    @IBAction func addPhotosTapped(sender: AnyObject) {
        let controller = PhotoCaptureViewController() { assets in
//            NSLog("Done with \(images.count) images")
//            self.images = images
//            self.tableView.reloadData()
        }
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