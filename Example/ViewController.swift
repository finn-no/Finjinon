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
                self.tableView.insertRows(at: [IndexPath(row: i, section: 0)], with: .automatic)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    @IBAction func addPhotosTapped(_ sender: AnyObject) {
        present(captureController, animated: true, completion: nil)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return assets.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ItemCell", for: indexPath) 
        let asset = assets[(indexPath as NSIndexPath).row]
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
    func photoCaptureViewController(_ controller: PhotoCaptureViewController, cellForItemAtIndexPath indexPath: IndexPath) -> PhotoCollectionViewCell? {
        return controller.dequeuedReusableCellForClass(PhotoCollectionViewCell.self, indexPath: indexPath) { cell in
            let asset = self.assets[(indexPath as NSIndexPath).item]
            // Set a thumbnail form the source image, or add your own network fetch code etc
            if let _ = asset.imageURL {

            } else {
                asset.imageWithWidth(cell.imageView.bounds.width) { image in
                    cell.imageView.image = image
                }
            }
        }
    }

    func photoCaptureViewControllerDidFinish(_ controller: PhotoCaptureViewController) {

    }

    func photoCaptureViewController(_ controller: PhotoCaptureViewController, didSelectAssetAtIndexPath indexPath: IndexPath) {
        NSLog("tapped in \((indexPath as NSIndexPath).row)")
    }

    func photoCaptureViewController(_ controller: PhotoCaptureViewController, didFailWithError error: NSError) {
        NSLog("failure: \(error)")
    }

    func photoCaptureViewController(_ controller: PhotoCaptureViewController, didMoveItemFromIndexPath fromIndexPath: IndexPath, toIndexPath: IndexPath) {
        NSLog("moved from #\((fromIndexPath as NSIndexPath).item) to #\((toIndexPath as NSIndexPath).item)")
        tableView.moveRow(at: fromIndexPath, to: toIndexPath)
    }

    func photoCaptureViewControllerNumberOfAssets(_ controller: PhotoCaptureViewController) -> Int {
        return assets.count
    }

    func photoCaptureViewController(_ controller: PhotoCaptureViewController, assetForIndexPath indexPath: IndexPath) -> Asset {
        return assets[(indexPath as NSIndexPath).item]
    }

    func photoCaptureViewController(_ controller: PhotoCaptureViewController, didAddAsset asset: Asset) {
        assets.append(asset)
        tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
    }

    func photoCaptureViewController(_ controller: PhotoCaptureViewController, deleteAssetAtIndexPath indexPath: IndexPath) {
        assets.remove(at: (indexPath as NSIndexPath).item)
        tableView.deleteRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
    }

    func photoCaptureViewController(_ controller: PhotoCaptureViewController, canMoveItemAtIndexPath indexPath: IndexPath) -> Bool {
        return true
    }
}
