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
    private var captureButton: TriggerButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = UIColor.blackColor()

        captureButton = TriggerButton(frame: CGRect(x: (view.frame.width/2)-33, y: view.frame.height-66-10 , width: 66, height: 66))
        captureButton.layer.cornerRadius = 33
        captureButton.addTarget(self, action: Selector("capturePhotoTapped:"), forControlEvents: .TouchUpInside)
        view.addSubview(captureButton)
        captureButton.enabled = false

        previewView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: captureButton.frame.minY - 10))
        view.addSubview(previewView)
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
        captureManager.captureImage { (image, metadata) in
            sender.enabled = true
            NSLog("captured image: \(image)")
            // TODO: shutter effect
        }
    }
}
