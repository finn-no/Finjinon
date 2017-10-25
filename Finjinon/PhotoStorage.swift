//
//  Copyright (c) 2017 FINN.no AS. All rights reserved.
//

import UIKit
import ImageIO
import AssetsLibrary

public enum AssetImageDataSourceTypes {
    case camera, library, unknown
}

public struct Asset: Equatable, CustomStringConvertible {
    public let UUID = Foundation.UUID().uuidString
    let storage: PhotoStorage
    struct Remote {
        let url: URL
        let originalDimensions: CGSize
    }

    fileprivate let remoteReference: Remote?
    public var imageURL: URL? {
        return remoteReference?.url
    }

    internal init(storage: PhotoStorage, imageURL: URL, originalDimensions: CGSize) {
        self.storage = storage
        remoteReference = Remote(url: imageURL, originalDimensions: originalDimensions)
    }

    internal init(storage: PhotoStorage) {
        self.storage = storage
        remoteReference = nil
    }

    public func originalImage(_ result: @escaping (UIImage) -> Void) {
        storage.imageForAsset(self, completion: result)
    }

    public func imageWithWidth(_ width: CGFloat, result: @escaping (UIImage) -> Void) {
        storage.thumbnailForAsset(self, forWidth: width, completion: result)
    }

    public func dimensions() -> CGSize {
        if let remote = self.remoteReference {
            return remote.originalDimensions
        } else {
            return storage.dimensionsforAsset(self)
        }
    }

    public var imageDataSourceType: AssetImageDataSourceTypes = .unknown

    public var description: String {
        return "<\(type(of: self)) UUID: \(UUID)>"
    }
}

public func ==(lhs: Asset, rhs: Asset) -> Bool {
    return lhs.UUID == rhs.UUID
}

// Public API for creating Asset's
open class PhotoStorage {
    fileprivate let baseURL: URL
    fileprivate let queue = DispatchQueue(label: "no.finn.finjonon.disk-cache-writes", attributes: [])
    fileprivate let resizeQueue = DispatchQueue(label: "no.finn.finjonon.disk-cache-resizes", attributes: DispatchQueue.Attributes.concurrent)
    fileprivate let fileManager = FileManager()
    fileprivate var cache: [String: Asset] = [:]
    fileprivate let assetLibrary = ALAssetsLibrary()

    init() {
        var cacheURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).last!
        cacheURL = cacheURL.appendingPathComponent("no.finn.finjonon.disk-cache")
        baseURL = cacheURL.appendingPathComponent(NSUUID().uuidString)
    }

    deinit {
        var error: NSError?
        if fileManager.fileExists(atPath: baseURL.path) {
            do {
                try fileManager.removeItem(at: baseURL)
            } catch let error1 as NSError {
                error = error1
                NSLog("PhotoDiskCache: failed to cleanup cache dir at \(baseURL): \(String(describing: error))")
            }
        }
    }

    // MARK: - API

    func createAssetFromImageData(_ data: Data, completion: @escaping (Asset) -> Void) {
        queue.async {
            let asset = Asset(storage: self)
            let cacheURL = self.cacheURLForAsset(asset)
            var error: NSError?
            do {
                try data.write(to: URL(fileURLWithPath: cacheURL.path), options: .atomic)
            } catch let error1 as NSError {
                error = error1
                NSLog("Failed to write image to \(cacheURL): \(String(describing: error))")
            } catch {
                fatalError()
            }
            DispatchQueue.main.async {
                completion(asset)
            }
        }
    }

    func createAssetFromImageURL(_ imageURL: URL, dimensions: CGSize, completion: @escaping (Asset) -> Void) {
        queue.async {
            let asset = Asset(storage: self, imageURL: imageURL, originalDimensions: dimensions)

            DispatchQueue.main.async {
                completion(asset)
            }
        }
    }

    func createAssetFromImage(_ image: UIImage, completion: @escaping (Asset) -> Void) {
        let data = UIImageJPEGRepresentation(image, 1.0)!
        createAssetFromImageData(data, completion: completion)
    }

    func createAssetFromAssetLibraryURL(_ assetURL: URL, completion: @escaping (Asset) -> Void) {
        assetLibrary.asset(for: assetURL, resultBlock: { asset in
            let assetHandler: (ALAsset) -> Void = { asset in
                guard let representation = asset.defaultRepresentation() else { return }

                let bufferLength = Int((representation.size()))
                let data = NSMutableData(length: bufferLength)!
                let buffer = UnsafeMutablePointer<UInt8>(OpaquePointer(data.mutableBytes))

                var error: NSError?
                let bytesWritten = representation.getBytes(buffer, fromOffset: 0, length: bufferLength, error: &error)
                if bytesWritten != bufferLength {
                    NSLog("failed to get all bytes (wrote \(bytesWritten)/\(bufferLength)): \(String(describing: error))")
                }
                self.createAssetFromImageData(data as Data, completion: completion)
            }

            if asset != nil {
                assetHandler(asset!)
            } else {
                // On iOS 8.1 [library assetForUrl] for Photo Streams always returns nil. Try to obtain it in an alternative way
                // http://stackoverflow.com/questions/26480526/alassetslibrary-assetforurl-always-returning-nil-for-photos-in-my-photo-stream
                self.assetLibrary.enumerateGroups(withTypes: ALAssetsGroupType(ALAssetsGroupPhotoStream), using: { group, stop in
                    if let group = group {
                        group.enumerateAssets(options: .reverse, using: { result, _, innerStop in
                            if let result = result, result.defaultRepresentation().url() == assetURL {
                                assetHandler(result)
                                innerStop?.initialize(to: true)
                                stop?.initialize(to: true)
                            }
                        })
                    }
                }, failureBlock: { error in
                    NSLog("failed to retrive ALAsset in 8.1 workaround: \(String(describing: error))")
                })
            }
        }, failureBlock: { error in
            NSLog("failed to retrive ALAsset: \(String(describing: error))")
        })
    }

    func deleteAsset(_ asset: Asset, completion: @escaping () -> Void) {
        queue.async {
            let cacheURL = self.cacheURLForAsset(asset)
            var error: NSError?
            do {
                try self.fileManager.removeItem(atPath: cacheURL.path)
            } catch let error1 as NSError {
                error = error1
                NSLog("failed failed to remove asset at \(cacheURL): \(String(describing: error))")
            } catch {
                fatalError()
            }
            DispatchQueue.main.async(execute: completion)
        }
    }

    func dimensionsforAsset(_ asset: Asset) -> CGSize {
        let cacheFileURL = cacheURLForAsset(asset)
        if let source = CGImageSourceCreateWithURL(cacheFileURL as CFURL, nil),
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

    fileprivate func imageForAsset(_ asset: Asset, completion: @escaping (UIImage) -> Void) {
        queue.async {
            let path = self.cacheURLForAsset(asset).path
            let image = UIImage(contentsOfFile: path)!
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }

    fileprivate func thumbnailForAsset(_ asset: Asset, forWidth width: CGFloat, completion: @escaping (UIImage) -> Void) {
        resizeQueue.async {
            let imageURL = self.cacheURLForAsset(asset)
            if let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil) {
                let options = [
                    kCGImageSourceThumbnailMaxPixelSize as NSString: width * UIScreen.main.scale,
                    kCGImageSourceCreateThumbnailWithTransform as NSString: kCFBooleanTrue,
                    kCGImageSourceCreateThumbnailFromImageAlways as NSString: kCFBooleanTrue,
                ] as [NSString: Any]

                if let thumbnailCGImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary?) {
                    let thumbnailImage = UIImage(cgImage: thumbnailCGImage)
                    DispatchQueue.main.async {
                        completion(thumbnailImage)
                    }
                }
            }
        }
    }

    fileprivate func cacheURLForAsset(_ asset: Asset) -> URL {
        ensureCacheDirectoryExists()
        return baseURL.appendingPathComponent(asset.UUID)
    }

    fileprivate func ensureCacheDirectoryExists() {
        if !fileManager.fileExists(atPath: baseURL.path) {
            var error: NSError?
            do {
                try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)
            } catch let error1 as NSError {
                error = error1
                NSLog("Failed to create cache directory at \(baseURL): \(String(describing: error))")
            }
        }
    }
}
