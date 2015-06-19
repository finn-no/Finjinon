//
//  PhotoCache.swift
//  Finjinon
//
//  Created by Sørensen, Johan on 18.06.15.
//  Copyright (c) 2015 FINN.no AS. All rights reserved.
//

import UIKit
import ImageIO

// TODO also support ALAsset/PHPhoto

public struct Asset {
    let UUID = NSUUID().UUIDString
    let storage: PhotoDiskCache
    // TODO: connect each asset with the/a cache and have method for retriving images on Asset itself? (alá ALAsset)
    // that way we only have to expose the asset as API

    internal init(storage: PhotoDiskCache) {
        self.storage = storage
    }

    public func retrieveOriginalImage(completion: UIImage -> Void) {
        storage.imageForAsset(self, completion: completion)
    }

    public func retrieveImageWithWidth(width: CGFloat, completion: UIImage -> Void) {
        storage.thumbnailForAsset(self, forWidth: width, completion: completion)
    }
}

// Public API for creating Asset's
public class PhotoStorage {
    let storage = PhotoDiskCache()

    func createAssetFromImageData(data: NSData, completion: Asset -> Void) {
        storage.createAssetFromImageData(data, completion: completion)
    }

    func createAssetFromImage(image: UIImage, completion: Asset -> Void) {
        let data = UIImageJPEGRepresentation(image, 1.0)
        createAssetFromImageData(data, completion: completion)
    }
}

// Stores images on disk to save memory, provides thumbnails, access is done in a serialized manner
internal class PhotoDiskCache {
    private let baseURL: NSURL
    private let queue = dispatch_queue_create("no.finn.finjonon.disk-cache-writes", DISPATCH_QUEUE_SERIAL)
    private let resizeQueue = dispatch_queue_create("no.finn.finjonon.disk-cache-resizes", DISPATCH_QUEUE_CONCURRENT)
    private let fileManager = NSFileManager()
    private var cache: [String: Asset] = [:]

    init() {
        let cacheURL = fileManager.URLsForDirectory(.CachesDirectory, inDomains: .UserDomainMask).last as! NSURL
        self.baseURL = cacheURL.URLByAppendingPathComponent("no.finn.finjonon.disk-cache")
        if !fileManager.fileExistsAtPath(self.baseURL.path!) {
            var error: NSError?
            if !fileManager.createDirectoryAtURL(self.baseURL, withIntermediateDirectories: true, attributes: nil, error: &error) {
                NSLog("Failed to create cache directory at \(baseURL): \(error)")
            }
        }
    }

    deinit {
        var error: NSError?
        if !fileManager.removeItemAtURL(baseURL, error: &error) {
            NSLog("PhotoDiskCache: failed to cleanup cache dir at \(baseURL): \(error)")
        }
    }

    // MARK: - API

    func createAssetFromImageData(data: NSData, completion: Asset -> Void) {
        dispatch_async(queue) {
            let asset = Asset(storage: self)
            let cacheURL = self.cacheURLForAsset(asset)
            var error: NSError?
            if !data.writeToFile(cacheURL.path!, options: .DataWritingAtomic, error: &error) {
                NSLog("Failed to write image to \(cacheURL): \(error)")
                // TODO: throw
            }
            dispatch_async(dispatch_get_main_queue()) {
                completion(asset)
            }
        }
    }

    //func createAssetFromALAsset(asset: ALAsset) -> Asset {

    // MARK: - Internal

    func imageForAsset(asset: Asset, completion: UIImage -> Void) {
        dispatch_async(queue) {
            let path = self.cacheURLForAsset(asset).path!
            let image = UIImage(contentsOfFile: path)!
            dispatch_async(dispatch_get_main_queue()) {
                completion(image)
            }
        }
    }

    func thumbnailForAsset(asset: Asset, forWidth width: CGFloat, completion: UIImage -> Void) {
        dispatch_async(self.resizeQueue) {
            let imageURL = self.cacheURLForAsset(asset)
            if let imageSource = CGImageSourceCreateWithURL(imageURL, nil) {
                let options = [ kCGImageSourceThumbnailMaxPixelSize as NSString: width,
                    kCGImageSourceCreateThumbnailWithTransform as NSString: kCFBooleanTrue,
                    kCGImageSourceCreateThumbnailFromImageIfAbsent as NSString: kCFBooleanTrue,
                ]

                let thumbnailImage = UIImage(CGImage: CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options))

                dispatch_async(dispatch_get_main_queue()) {
                    completion(thumbnailImage!)
                }
            } // TODO else throws
        }
    }

    func deleteAsset(asset: Asset, completion: () -> Void) {
        dispatch_async(queue) {
            let cacheURL = self.cacheURLForAsset(asset)
            var error: NSError?
            if self.fileManager.removeItemAtPath(cacheURL.path!, error: &error) {
                NSLog("failed failed to remove asset at \(cacheURL): \(error)")
            }
            dispatch_async(dispatch_get_main_queue(), completion)
        }
    }

    private func cacheURLForAsset(asset: Asset) -> NSURL {
        return baseURL.URLByAppendingPathComponent(asset.UUID)
    }
}
