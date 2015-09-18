//
//  PhotoCache.swift
//  Finjinon
//
//  Created by Sørensen, Johan on 18.06.15.
//  Copyright (c) 2015 FINN.no AS. All rights reserved.
//

import UIKit
import ImageIO
import AssetsLibrary

// TODO also support ALAsset/PHPhoto

public struct Asset: Equatable, CustomStringConvertible {
    let UUID = NSUUID().UUIDString
    let storage: PhotoStorage
    struct Remote {
        let url: NSURL
        let originalDimensions: CGSize
    }
    private let remoteReference: Remote?
    public var imageURL: NSURL? {
        return remoteReference?.url
    }

    internal init(storage: PhotoStorage, imageURL: NSURL, originalDimensions: CGSize) {
        self.storage = storage
        self.remoteReference = Remote(url: imageURL, originalDimensions: originalDimensions)
    }

    internal init(storage: PhotoStorage) {
        self.storage = storage
        self.remoteReference = nil
    }

    public func originalImage(result: UIImage -> Void) {
        storage.imageForAsset(self, completion: result)
    }

    public func imageWithWidth(width: CGFloat, result: UIImage -> Void) {
        storage.thumbnailForAsset(self, forWidth: width, completion: result)
    }

    public func dimensions() -> CGSize {
        if let remote = self.remoteReference {
            return remote.originalDimensions
        } else {
            return storage.dimensionsforAsset(self)
        }
    }

    public var description: String {
        return "<\(self.dynamicType) UUID: \(UUID)>"
    }
}

public func ==(lhs: Asset, rhs: Asset) -> Bool {
    return lhs.UUID == rhs.UUID
}


// Public API for creating Asset's
public class PhotoStorage {
    private let baseURL: NSURL
    private let queue = dispatch_queue_create("no.finn.finjonon.disk-cache-writes", DISPATCH_QUEUE_SERIAL)
    private let resizeQueue = dispatch_queue_create("no.finn.finjonon.disk-cache-resizes", DISPATCH_QUEUE_CONCURRENT)
    private let fileManager = NSFileManager()
    private var cache: [String: Asset] = [:]
    private let assetLibrary = ALAssetsLibrary()

    init() {
        var cacheURL = fileManager.URLsForDirectory(.CachesDirectory, inDomains: .UserDomainMask).last!
        cacheURL = cacheURL.URLByAppendingPathComponent("no.finn.finjonon.disk-cache")
        self.baseURL = cacheURL.URLByAppendingPathComponent(NSUUID().UUIDString)
    }

    deinit {
        var error: NSError?
        if fileManager.fileExistsAtPath(baseURL.path!) {
            do {
                try fileManager.removeItemAtURL(baseURL)
            } catch let error1 as NSError {
                error = error1
                NSLog("PhotoDiskCache: failed to cleanup cache dir at \(baseURL): \(error)")
            }
        }
    }

    // MARK: - API

    func createAssetFromImageData(data: NSData, completion: Asset -> Void) {
        dispatch_async(queue) {
            let asset = Asset(storage: self)
            let cacheURL = self.cacheURLForAsset(asset)
            var error: NSError?
            do {
                try data.writeToFile(cacheURL.path!, options: .DataWritingAtomic)
            } catch let error1 as NSError {
                error = error1
                NSLog("Failed to write image to \(cacheURL): \(error)")
                // TODO: throw
            } catch {
                fatalError()
            }
            dispatch_async(dispatch_get_main_queue()) {
                completion(asset)
            }
        }
    }

    func createAssetFromImageURL(imageURL: NSURL, dimensions: CGSize, completion: Asset -> Void) {
        dispatch_async(queue) {
            let asset = Asset(storage: self, imageURL: imageURL, originalDimensions: dimensions)

            dispatch_async(dispatch_get_main_queue()) {
                completion(asset)
            }
        }
    }

    func createAssetFromImage(image: UIImage, completion: Asset -> Void) {
        let data = UIImageJPEGRepresentation(image, 1.0)!
        createAssetFromImageData(data, completion: completion)
    }

    func createAssetFromAssetLibraryURL(assetURL: NSURL, completion: Asset -> Void) {
        assetLibrary.assetForURL(assetURL, resultBlock: { asset in
            let assetHandler: ALAsset -> Void = { asset in
                let representation = asset.defaultRepresentation()
                let bufferLength = Int(representation.size())
                let data = NSMutableData(length: bufferLength)!
                let buffer = UnsafeMutablePointer<UInt8>(data.mutableBytes)

                var error: NSError?
                let bytesWritten = representation.getBytes(buffer, fromOffset: 0, length: bufferLength, error: &error)
                if bytesWritten != bufferLength {
                    NSLog("failed to get all bytes (wrote \(bytesWritten)/\(bufferLength)): \(error)")
                }
                self.createAssetFromImageData(data, completion: completion)
            }

            if asset != nil {
                assetHandler(asset)
            } else {
                // On iOS 8.1 [library assetForUrl] for Photo Streams always returns nil. Try to obtain it in an alternative way
                // http://stackoverflow.com/questions/26480526/alassetslibrary-assetforurl-always-returning-nil-for-photos-in-my-photo-stream
                self.assetLibrary.enumerateGroupsWithTypes(ALAssetsGroupType(ALAssetsGroupPhotoStream), usingBlock: { (group, stop: UnsafeMutablePointer<ObjCBool>) in
                    if let group = group {
                        group.enumerateAssetsWithOptions(.Reverse, usingBlock: { (result, index, innerStop) in
                            if let result = result where result.defaultRepresentation().url() == assetURL {
                                assetHandler(result)
                                innerStop.initialize(true)
                                stop.initialize(true)
                            }
                        })
                    }
                    }, failureBlock: { error in
                        NSLog("failed to retrive ALAsset in 8.1 workaround: \(error)")
                })
            }
            }, failureBlock: { error in
                NSLog("failed to retrive ALAsset: \(error)")
        })
    }

    func deleteAsset(asset: Asset, completion: () -> Void) {
        dispatch_async(queue) {
            let cacheURL = self.cacheURLForAsset(asset)
            var error: NSError?
            do {
                try self.fileManager.removeItemAtPath(cacheURL.path!)
            } catch let error1 as NSError {
                error = error1
                NSLog("failed failed to remove asset at \(cacheURL): \(error)")
            } catch {
                fatalError()
            }
            dispatch_async(dispatch_get_main_queue(), completion)
        }
    }

    func dimensionsforAsset(asset: Asset) -> CGSize {
        let cacheFileURL = self.cacheURLForAsset(asset)
        if let source = CGImageSourceCreateWithURL(cacheFileURL, nil) {
            let imageProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as! NSDictionary
            if let width = imageProperties[kCGImagePropertyPixelWidth as String] as? CGFloat,
                let height = imageProperties[kCGImagePropertyPixelHeight as String] as? CGFloat {
                    return CGSize(width: width, height: height)
            }
        } else {
            NSLog("*** Warning: failed to get CGImagePropertyPixel{Width,Height} from \(cacheFileURL)")
            return CGSize.zero
        }
    }

    // MARK: - Private

    private func imageForAsset(asset: Asset, completion: UIImage -> Void) {
        dispatch_async(queue) {
            let path = self.cacheURLForAsset(asset).path!
            let image = UIImage(contentsOfFile: path)!
            dispatch_async(dispatch_get_main_queue()) {
                completion(image)
            }
        }
    }

    private func thumbnailForAsset(asset: Asset, forWidth width: CGFloat, completion: UIImage -> Void) {
        dispatch_async(self.resizeQueue) {
            let imageURL = self.cacheURLForAsset(asset)
            if let imageSource = CGImageSourceCreateWithURL(imageURL, nil) {
                let options = [ kCGImageSourceThumbnailMaxPixelSize as NSString: width * UIScreen.mainScreen().scale,
                    kCGImageSourceCreateThumbnailWithTransform as NSString: kCFBooleanTrue,
                    kCGImageSourceCreateThumbnailFromImageAlways as NSString: kCFBooleanTrue,
                ]

                if let thumbnailCGImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options) {
                    let thumbnailImage = UIImage(CGImage: thumbnailCGImage)
                    dispatch_async(dispatch_get_main_queue()) {
                        completion(thumbnailImage)
                    }
                }
            } // TODO else throws
        }
    }

    private func cacheURLForAsset(asset: Asset) -> NSURL {
        ensureCacheDirectoryExists()
        return baseURL.URLByAppendingPathComponent(asset.UUID)
    }

    private func ensureCacheDirectoryExists() {
        if !fileManager.fileExistsAtPath(self.baseURL.path!) {
            var error: NSError?
            do {
                try fileManager.createDirectoryAtURL(self.baseURL, withIntermediateDirectories: true, attributes: nil)
            } catch let error1 as NSError {
                error = error1
                NSLog("Failed to create cache directory at \(baseURL): \(error)")
            }
        }
    }
}
