//
//  Copyright (c) 2017 FINN.no AS. All rights reserved.
//

import UIKit
import ImageIO
import Photos

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

    private let remoteReference: Remote?
    public var imageURL: URL? {
        return remoteReference?.url
    }

    init(storage: PhotoStorage, imageURL: URL, originalDimensions: CGSize) {
        self.storage = storage
        remoteReference = Remote(url: imageURL, originalDimensions: originalDimensions)
    }

    init(storage: PhotoStorage) {
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
    private let baseURL: URL
    private let queue = DispatchQueue(label: "no.finn.finjonon.disk-cache-writes", attributes: [])
    private let resizeQueue = DispatchQueue(label: "no.finn.finjonon.disk-cache-resizes", attributes: DispatchQueue.Attributes.concurrent)
    private let fileManager = FileManager()
    private var cache: [String: Asset] = [:]

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
        guard let data = image.jpegData(compressionQuality: 1.0) else { return }
        createAssetFromImageData(data, completion: completion)
    }

    func createAssetFromAssetLibraryURL(_ assetURL: URL, completion: @escaping (Asset) -> Void) {
        let assetHandler: (PHAsset) -> Void = { asset in
            let imageManager = PHImageManager.default()
            let imageRequestOptions = PHImageRequestOptions()
            imageRequestOptions.version = .original
            imageRequestOptions.isSynchronous = true

            imageManager.requestImageData(for: asset, options: imageRequestOptions) { (imageData, _, _, _) in
                guard let imageData = imageData else { return }
                self.createAssetFromImageData(imageData as Data, completion: completion)
            }
        }

        let asset = PHAsset.fetchAssets(withALAssetURLs: [assetURL], options: nil).firstObject
        if let validAsset = asset {
            assetHandler(validAsset)
        } else {
            let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
            collections.enumerateObjects { (collection, _, stop) in
                let assets = PHAsset.fetchAssets(in: collection, options: nil)

                assets.enumerateObjects({ (asset, _, nestedStop) in
                    // Need to access URL of the PHAsset
                    asset.requestContentEditingInput(with: nil, completionHandler: { (editingInput, _) in
                        if let url = editingInput?.fullSizeImageURL {
                            if assetURL == url {
                                assetHandler(asset)
                                nestedStop.initialize(to: true)
                                stop.initialize(to: true)
                            }
                        }
                    })
                })
            }
        }
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
}

// MARK: - Private methods

private extension PhotoStorage {
    func imageForAsset(_ asset: Asset, completion: @escaping (UIImage) -> Void) {
        queue.async {
            let path = self.cacheURLForAsset(asset).path
            let image = UIImage(contentsOfFile: path)!
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }

    func thumbnailForAsset(_ asset: Asset, forWidth width: CGFloat, completion: @escaping (UIImage) -> Void) {
        resizeQueue.async {
            let imageURL = self.cacheURLForAsset(asset)
            if let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil) {
                let options = [
                    kCGImageSourceThumbnailMaxPixelSize as NSString: width * UIScreen.main.scale,
                    kCGImageSourceCreateThumbnailWithTransform as NSString: kCFBooleanTrue,
                    kCGImageSourceCreateThumbnailFromImageAlways as NSString: kCFBooleanTrue
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

    private func cacheURLForAsset(_ asset: Asset) -> URL {
        ensureCacheDirectoryExists()
        return baseURL.appendingPathComponent(asset.UUID)
    }

    private func ensureCacheDirectoryExists() {
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
