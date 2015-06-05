//
//  ViewController.swift
//  Finjinon
//
//  Created by johsoren on 06/04/2015.
//  Copyright (c) 06/04/2015 johsoren. All rights reserved.
//

import UIKit

class ViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    @IBAction func addPhotosTapped(sender: AnyObject) {
        // TODO: push the camera view controller
        let controller = PhotoCaptureViewController()
        navigationController?.pushViewController(controller, animated: true)
    }
}