//
//  ImagePickerAdapter.swift
//  Finjinon
//
//  Created by Sørensen, Johan on 22.06.15.
//  Copyright (c) 2015 FINN.no AS. All rights reserved.
//

import UIKit
import MobileCoreServices
import Photos

public protocol ImagePickerAdapter {
    // Return a UIViewController suitable for picking one or more images. The supplied selectionHandler may be called more than once.
    // the argument is a dictionary with either (or both) the UIImagePickerControllerOriginalImage or UIImagePickerControllerReferenceURL keys
    // The completion handler will be called when done, supplying the caller with a didCancel flag which will be true
    // if the user cancelled the image selection process.
    // NOTE: The caller is responsible for dismissing any presented view controllers in the completion handler.
    func viewControllerForImageSelection(_ selectedAssetsHandler: ([PHAsset]) -> Void, completion: (Bool) -> Void) -> UIViewController
}


public class ImagePickerControllerAdapter: NSObject, ImagePickerAdapter, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    var selectionHandler: ([PHAsset]) -> Void = { _ in }
    var completionHandler: (didCancel: Bool) -> Void = { _ in }

    public func viewControllerForImageSelection(_ selectedAssetsHandler: ([PHAsset]) -> Void, completion: (Bool) -> Void) -> UIViewController {
        self.selectionHandler = selectedAssetsHandler
        self.completionHandler = completion

        let picker = UIImagePickerController()
        picker.mediaTypes = [kUTTypeImage as String]
        picker.delegate = self

        return picker
    }

    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        guard let referenceURL = info[UIImagePickerControllerReferenceURL] as? URL else {
            completionHandler(didCancel: true)
            return
        }

        let fetchResult = PHAsset.fetchAssets(withALAssetURLs: [referenceURL], options: nil)
        if let asset = fetchResult.firstObject {
            selectionHandler([asset])
            completionHandler(didCancel: false)
        } else {
            NSLog("*** Failed to fetch PHAsset for asset library URL: \(referenceURL): \(fetchResult.firstObject)")
            completionHandler(didCancel: true)
        }
    }

    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        completionHandler(didCancel: true)
    }
}
