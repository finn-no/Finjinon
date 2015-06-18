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
        let image = UIImage(named: "hoff.jpeg")!
        let controller = PhotoCaptureViewController(images: [image])
        presentViewController(controller, animated: true, completion: nil)
    }
}