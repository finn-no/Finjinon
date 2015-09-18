//
//  ImagePickerAdapter.swift
//  Finjinon
//
//  Created by Sørensen, Johan on 22.06.15.
//  Copyright (c) 2015 FINN.no AS. All rights reserved.
//

import UIKit
import MobileCoreServices

public protocol ImagePickerAdapter {
    // Return a UIViewController suitable for picking one or more images. The supplied selectionHandler may be called more than once.
    // the argument is a dictionary with either (or both) the UIImagePickerControllerOriginalImage or UIImagePickerControllerReferenceURL keys
    // The completion handler will be called when done, supplying the caller with a didCancel flag which will be true
    // if the user cancelled the image selection process.
    // NOTE: The caller is responsible for dismissing any presented view controllers in the completion handler.
    func viewControllerForImageSelection(selectionHandler: [NSObject : AnyObject] -> Void, completion: Bool -> Void) -> UIViewController
}


public class ImagePickerControllerAdapter: NSObject, ImagePickerAdapter, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    var selectionHandler: [NSObject : AnyObject] -> Void = { _ in }
    var completionHandler: Bool -> Void = { _ in }

    public func viewControllerForImageSelection(selectionHandler: [NSObject : AnyObject] -> Void, completion: Bool -> Void) -> UIViewController {
        self.selectionHandler = selectionHandler
        self.completionHandler = completion

        let picker = UIImagePickerController()
        picker.mediaTypes = [kUTTypeImage as String]
        picker.delegate = self

        return picker
    }

    public func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        selectionHandler(info)
        completionHandler(false)
    }

    public func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        completionHandler(true)
    }
}
