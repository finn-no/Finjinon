//
//  Copyright (c) 2017 FINN.no AS. All rights reserved.
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
    func viewControllerForImageSelection(_ selectedAssetsHandler: @escaping ([PHAsset]) -> Void, completion: @escaping (Bool) -> Void) -> UIViewController
}

open class ImagePickerControllerAdapter: NSObject, ImagePickerAdapter, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    var selectionHandler: ([PHAsset]) -> Void = { _ in }
    var completionHandler: (_ didCancel: Bool) -> Void = { _ in }

    open func viewControllerForImageSelection(_ selectedAssetsHandler: @escaping ([PHAsset]) -> Void, completion: @escaping (Bool) -> Void) -> UIViewController {
        selectionHandler = selectedAssetsHandler
        completionHandler = completion

        let picker = UIImagePickerController()
        picker.mediaTypes = [kUTTypeImage as String]
        picker.delegate = self

        return picker
    }

    open func imagePickerController(_: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        guard let referenceURL = info[.referenceURL] as? URL else {
            completionHandler(true)
            return
        }

        let fetchResult = PHAsset.fetchAssets(withALAssetURLs: [referenceURL], options: nil)
        if let asset = fetchResult.firstObject {
            selectionHandler([asset])
            completionHandler(false)
        } else {
            NSLog("*** Failed to fetch PHAsset for asset library URL: \(referenceURL): \(String(describing: fetchResult.firstObject))")
            completionHandler(true)
        }
    }

    open func imagePickerControllerDidCancel(_: UIImagePickerController) {
        completionHandler(true)
    }
}
