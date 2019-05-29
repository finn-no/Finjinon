//
//  Copyright (c) 2019 FINN.no AS. All rights reserved.
//

import CoreMedia

final class LowLightService {
    private let maxNumberOfResults = 3
    private var results = [LightingCondition]()

    func getLightningCondition(from sampleBuffer: CMSampleBuffer) -> LightingCondition? {
        let rawMetadata = CMCopyDictionaryOfAttachments(
            allocator: nil,
            target: sampleBuffer,
            attachmentMode: CMAttachmentMode(kCMAttachmentMode_ShouldPropagate)
        )

        do {
            let metadata = CFDictionaryCreateCopy(nil, rawMetadata) as NSDictionary
            let exifData: NSDictionary = try metadata.value(forKey: "{Exif}")
            let fNumber: Double = try exifData.value(forKey: kCGImagePropertyExifFNumber)
            let exposureTime: Double = try exifData.value(forKey: kCGImagePropertyExifExposureTime)
            let isoSpeedRatings: NSArray = try exifData.value(forKey: kCGImagePropertyExifISOSpeedRatings)

            guard let isoSpeedRating = isoSpeedRatings[0] as? Double else {
                throw MetatataError()
            }

            let explosureValue = log2((100 * fNumber * fNumber) / (exposureTime * isoSpeedRating))
            let lightningCondition = LightingCondition(value: explosureValue)

            results.append(lightningCondition)

            if results.count == maxNumberOfResults + 1 {
                results = Array(results.dropFirst())
            }

            return results.count > 1 && Set(results).count == 1 ? lightningCondition : nil
        } catch {
            return nil
        }
    }
}

// MARK: - Private types

private extension NSDictionary {
    func value<T>(forKey key: CFString) throws -> T {
        return try value(forKey: key as String)
    }

    func value<T>(forKey key: String) throws -> T {
        guard let value = self[key] as? T else {
            throw MetatataError()
        }

        return value
    }
}

private struct MetatataError: Error {}
