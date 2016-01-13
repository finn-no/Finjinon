//
//  AssetResolver.swift
//  Finjinon
//
//  Created by Sørensen, Johan on 13.01.16.
//  Copyright © 2016 FINN.no AS. All rights reserved.
//

import Foundation
import Photos

internal struct AssetResolver {
    let queue = dispatch_queue_create("com.finjinon.asset-resolvement", DISPATCH_QUEUE_SERIAL)
    var defaultTargetSize = CGSize(width: 720, height: 1280)

    func enqueueResolve(asset: PHAsset, targetSize: CGSize? = nil, completion: UIImage -> Void) {
        dispatch_async(queue) {
            self.resolve(asset, completion: completion)
        }
    }

    func resolve(asset: PHAsset, targetSize: CGSize? = nil, completion: UIImage -> Void) {
        let manager = PHImageManager.defaultManager()

        let options = PHImageRequestOptions()
        options.deliveryMode = .HighQualityFormat
        options.resizeMode = .Fast

        let size = targetSize ?? defaultTargetSize
        manager.requestImageForAsset(asset, targetSize: size, contentMode: .AspectFill, options: options) { image, info in
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            if let image = image where !isDegraded {
                completion(image)
            }
        }
    }
}
