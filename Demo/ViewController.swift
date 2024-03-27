//
//  Copyright (c) 2017 FINN.no AS. All rights reserved.
//

import UIKit
import Finjinon

class ViewController: UITableViewController {
    var assets: [Asset] = []
    let captureController = PhotoCaptureViewController(client: nil)

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addPhotosTapped(_:)))
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ItemCell")

        captureController.delegate = self

        for i in 0 ..< 6 {
            captureController.createAssetFromImage(UIImage(named: "hoff.jpeg")!) { asset in
                self.assets.append(asset)
                self.tableView.insertRows(at: [IndexPath(row: i, section: 0)], with: .automatic)
            }
        }
        
        present(captureController, animated: true, completion: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    @objc func addPhotosTapped(_: AnyObject) {
        present(captureController, animated: true, completion: nil)
    }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return assets.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ItemCell", for: indexPath)
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
    func photoCaptureViewController(_ controller: PhotoCaptureViewController, cellForItemAtIndexPath indexPath: IndexPath) -> PhotoCollectionViewCell? {
        return controller.dequeuedReusableCellForClass(PhotoCollectionViewCell.self, indexPath: indexPath) { cell in
            let asset = self.assets[indexPath.item]
            // Set a thumbnail form the source image, or add your own network fetch code etc
            if let _ = asset.imageURL {

            } else {
                asset.imageWithWidth(cell.imageView.bounds.width) { image in
                    cell.imageView.image = image
                }
            }
        }
    }

    func photoCaptureViewControllerDidFinish(_: PhotoCaptureViewController) {
    }

    func photoCaptureViewController(_: PhotoCaptureViewController, didSelectAssetAtIndexPath indexPath: IndexPath) {
        NSLog("tapped in \(indexPath.row)")
    }

    func photoCaptureViewController(_: PhotoCaptureViewController, didFailWithError error: NSError) {
        NSLog("failure: \(error)")
    }

    func photoCaptureViewController(_: PhotoCaptureViewController, didMoveItemFromIndexPath fromIndexPath: IndexPath, toIndexPath: IndexPath) {
        NSLog("moved from #\(fromIndexPath.item) to #\(toIndexPath.item)")
        tableView.moveRow(at: fromIndexPath, to: toIndexPath)
    }

    func photoCaptureViewControllerNumberOfAssets(_: PhotoCaptureViewController) -> Int {
        return assets.count
    }

    func photoCaptureViewController(_: PhotoCaptureViewController, assetForIndexPath indexPath: IndexPath) -> Asset {
        return assets[indexPath.item]
    }

    func photoCaptureViewController(_: PhotoCaptureViewController, didAddAsset asset: Asset) {
        assets.append(asset)
        tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
    }

    func photoCaptureViewController(_: PhotoCaptureViewController, deleteAssetAtIndexPath indexPath: IndexPath) {
        assets.remove(at: indexPath.item)
        tableView.deleteRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
    }

    func photoCaptureViewController(_: PhotoCaptureViewController, canMoveItemAtIndexPath _: IndexPath) -> Bool {
        return true
    }
}
