//
//  PhotoCaptureViewController.swift
//  Finjinon
//
//  Created by Sørensen, Johan on 05.06.15.
//  Copyright (c) 2015 FINN.no AS. All rights reserved.
//

import UIKit
import AVFoundation

class PhotoCaptureViewController: UIViewController {
    private let captureManager = CaptureManager()
    private var previewView: UIView!
    private var captureButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = UIColor.blackColor()

        captureButton = UIButton(frame: CGRect(x: (view.frame.width/2)-33, y: view.frame.height-66-10 , width: 66, height: 66))
        captureButton.backgroundColor = UIColor.whiteColor()
        captureButton.layer.cornerRadius = 33
        captureButton.addTarget(self, action: Selector("capturePhotoTapped:"), forControlEvents: .TouchUpInside)
        view.addSubview(captureButton)
        captureButton.enabled = false

        previewView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: captureButton.frame.minY - 10))
        view.addSubview(previewView)
        previewView.layer.borderColor = UIColor.redColor().CGColor
        previewView.layer.borderWidth = 1.0
        let previewLayer = captureManager.previewLayer
        previewLayer.frame = previewView.bounds
        previewView.layer.addSublayer(previewLayer)

        captureManager.prepare {
            NSLog("CaptureManager fully initialized")

            self.captureButton.enabled = true
        }
    }

    func capturePhotoTapped(sender: UIButton) {
        sender.enabled = false
        sender.backgroundColor = UIColor.lightGrayColor()
        captureManager.captureImage { (image, metadata) in
            sender.enabled = true
            sender.backgroundColor = UIColor.whiteColor()
            NSLog("captured image: \(image)")
        }
    }
}
