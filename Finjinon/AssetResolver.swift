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
    let queue = DispatchQueue(label: "com.finjinon.asset-resolvement", attributes: [])
    var defaultTargetSize = CGSize(width: 720, height: 1280)

    func enqueueResolve(_ asset: PHAsset, targetSize: CGSize? = nil, completion: @escaping (UIImage) -> Void) {
        queue.async {
            self.resolve(asset, completion: completion)
        }
    }

    func resolve(_ asset: PHAsset, targetSize: CGSize? = nil, completion: @escaping (UIImage) -> Void) {
        let manager = PHImageManager.default()

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        let size = targetSize ?? defaultTargetSize
        manager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options) { image, info in
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            if let image = image, !isDegraded {
                completion(image)
            }
        }
    }
}
