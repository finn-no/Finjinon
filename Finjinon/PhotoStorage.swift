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
    public let UUID = Foundation.UUID().uuidString
    let storage: PhotoStorage
    struct Remote {
        let url: URL
        let originalDimensions: CGSize
    }
    private let remoteReference: Remote?
    public var imageURL: URL? {
        return remoteReference?.url
    }

    internal init(storage: PhotoStorage, imageURL: URL, originalDimensions: CGSize) {
        self.storage = storage
        self.remoteReference = Remote(url: imageURL, originalDimensions: originalDimensions)
    }

    internal init(storage: PhotoStorage) {
        self.storage = storage
        self.remoteReference = nil
    }

    public func originalImage(_ result: (UIImage) -> Void) {
        storage.imageForAsset(self, completion: result)
    }

    public func imageWithWidth(_ width: CGFloat, result: (UIImage) -> Void) {
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
    private let baseURL: URL
    private let queue = DispatchQueue(label: "no.finn.finjonon.disk-cache-writes", attributes: DispatchQueueAttributes.serial)
    private let resizeQueue = DispatchQueue(label: "no.finn.finjonon.disk-cache-resizes", attributes: DispatchQueueAttributes.concurrent)
    private let fileManager = FileManager()
    private var cache: [String: Asset] = [:]
    private let assetLibrary = ALAssetsLibrary()

    init() {
        var cacheURL = fileManager.urlsForDirectory(.cachesDirectory, inDomains: .userDomainMask).last!
        cacheURL = try! cacheURL.appendingPathComponent("no.finn.finjonon.disk-cache")
        self.baseURL = try! cacheURL.appendingPathComponent(UUID().uuidString)
    }

    deinit {
        var error: NSError?
        if fileManager.fileExists(atPath: baseURL.path!) {
            do {
                try fileManager.removeItem(at: baseURL)
            } catch let error1 as NSError {
                error = error1
                NSLog("PhotoDiskCache: failed to cleanup cache dir at \(baseURL): \(error)")
            }
        }
    }

    // MARK: - API

    func createAssetFromImageData(_ data: Data, completion: (Asset) -> Void) {
        queue.async {
            let asset = Asset(storage: self)
            let cacheURL = self.cacheURLForAsset(asset)
            var error: NSError?
            do {
                try data.write(to: URL(fileURLWithPath: cacheURL.path!), options: .dataWritingAtomic)
            } catch let error1 as NSError {
                error = error1
                NSLog("Failed to write image to \(cacheURL): \(error)")
                // TODO: throw
            } catch {
                fatalError()
            }
            DispatchQueue.main.async {
                completion(asset)
            }
        }
    }

    func createAssetFromImageURL(_ imageURL: URL, dimensions: CGSize, completion: (Asset) -> Void) {
        queue.async {
            let asset = Asset(storage: self, imageURL: imageURL, originalDimensions: dimensions)

            DispatchQueue.main.async {
                completion(asset)
            }
        }
    }

    func createAssetFromImage(_ image: UIImage, completion: (Asset) -> Void) {
        let data = UIImageJPEGRepresentation(image, 1.0)!
        createAssetFromImageData(data, completion: completion)
    }

    func createAssetFromAssetLibraryURL(_ assetURL: URL, completion: (Asset) -> Void) {
        assetLibrary.asset(for: assetURL, resultBlock: { asset in
            let assetHandler: (ALAsset) -> Void = { asset in
                let representation = asset.defaultRepresentation()
                let bufferLength = Int((representation?.size())!)
                let data = NSMutableData(length: bufferLength)!
                let buffer = UnsafeMutablePointer<UInt8>(data.mutableBytes)

                var error: NSError?
                let bytesWritten = representation?.getBytes(buffer, fromOffset: 0, length: bufferLength, error: &error)
                if bytesWritten != bufferLength {
                    NSLog("failed to get all bytes (wrote \(bytesWritten)/\(bufferLength)): \(error)")
                }
                self.createAssetFromImageData(data as Data, completion: completion)
            }

            if asset != nil {
                assetHandler(asset!)
            } else {
                // On iOS 8.1 [library assetForUrl] for Photo Streams always returns nil. Try to obtain it in an alternative way
                // http://stackoverflow.com/questions/26480526/alassetslibrary-assetforurl-always-returning-nil-for-photos-in-my-photo-stream
                self.assetLibrary.enumerateGroups(withTypes: ALAssetsGroupType(ALAssetsGroupPhotoStream), using: { (group, stop) in
                    if let group = group {
                        group.enumerateAssets(.reverse, using: { (result, index, innerStop) in
                            if let result = result where result.defaultRepresentation().url() == assetURL {
                                assetHandler(result)
                                innerStop?.initialize(with: true)
                                stop?.initialize(with: true)
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

    func deleteAsset(_ asset: Asset, completion: () -> Void) {
        queue.async {
            let cacheURL = self.cacheURLForAsset(asset)
            var error: NSError?
            do {
                try self.fileManager.removeItem(atPath: cacheURL.path!)
            } catch let error1 as NSError {
                error = error1
                NSLog("failed failed to remove asset at \(cacheURL): \(error)")
            } catch {
                fatalError()
            }
            DispatchQueue.main.async(execute: completion)
        }
    }

    func dimensionsforAsset(_ asset: Asset) -> CGSize {
        let cacheFileURL = self.cacheURLForAsset(asset)
        if let source = CGImageSourceCreateWithURL(cacheFileURL, nil),
            let imageProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as NSDictionary? {
                if let width = imageProperties[kCGImagePropertyPixelWidth as String] as? CGFloat,
                    let height = imageProperties[kCGImagePropertyPixelHeight as String] as? CGFloat {
                        return CGSize(width: width, height: height)
                }
                return CGSize.zero
        } else {
            NSLog("*** Warning: failed to get CGImagePropertyPixel{Width,Height} from \(cacheFileURL)")
            return CGSize.zero
        }
    }


    // MARK: - Private

    private func imageForAsset(_ asset: Asset, completion: (UIImage) -> Void) {
        queue.async {
            let path = self.cacheURLForAsset(asset).path!
            let image = UIImage(contentsOfFile: path)!
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }

    private func thumbnailForAsset(_ asset: Asset, forWidth width: CGFloat, completion: (UIImage) -> Void) {
        self.resizeQueue.async {
            let imageURL = self.cacheURLForAsset(asset)
            if let imageSource = CGImageSourceCreateWithURL(imageURL, nil) {
                let options = [ kCGImageSourceThumbnailMaxPixelSize as NSString: width * UIScreen.main().scale,
                    kCGImageSourceCreateThumbnailWithTransform as NSString: true,
                    kCGImageSourceCreateThumbnailFromImageAlways as NSString: true,
                ]

                if let thumbnailCGImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options) {
                    let thumbnailImage = UIImage(cgImage: thumbnailCGImage)
                    DispatchQueue.main.async {
                        completion(thumbnailImage)
                    }
                }
            } // TODO else throws
        }
    }

    private func cacheURLForAsset(_ asset: Asset) -> URL {
        ensureCacheDirectoryExists()
        return try! baseURL.appendingPathComponent(asset.UUID)
    }

    private func ensureCacheDirectoryExists() {
        if !fileManager.fileExists(atPath: self.baseURL.path!) {
            var error: NSError?
            do {
                try fileManager.createDirectory(at: self.baseURL, withIntermediateDirectories: true, attributes: nil)
            } catch let error1 as NSError {
                error = error1
                NSLog("Failed to create cache directory at \(baseURL): \(error)")
            }
        }
    }
}
