//
//  PredictionClient.swift
//
//
//  Created by Krister Sigvaldsen Moen on 26/03/2024.
//

import Foundation
import FINNClient

public struct AdInCameraTips: Codable {
    var item: String?
    var tips: [String]?
}

public struct CategoryGroup: Codable, Hashable {
    private enum CodingKeys: String, CodingKey {
        case main = "L1"
        case sub = "L2"
        case product = "L3"
        case probability
    }

    public let main: String
    public let sub: String?
    public let product: String?
    public let probability: String?

    var toDictionary: [String: Any] {
        let mainAsAny = main as Any
        let subAsAny = sub as Any
        let productAsAny = product as Any
        return [
            CodingKeys.main.rawValue: mainAsAny,
            CodingKeys.sub.rawValue: subAsAny,
            CodingKeys.product.rawValue: productAsAny
        ]
    }
}

public protocol PredictionClient: AnyObject {
    @discardableResult
    /// Uploads a image and gets tips with AI
    /// - Parameters:
    ///   - imageData: The image data.
    ///   - bodyBoundary: String to use for the boundary in the file upload.
    ///   - dataCallback: The completion handler to call when the request is completed.
    /// - Returns: A token to cancel ongoing request.
    func uploadImageAndGetTips(
        imageData: Data,
        bodyBoundary: String?,
        dataCallback: @escaping (Response<AdInCameraTips>) -> Void
    ) -> RequestToken?
    
    @discardableResult
    /// Uploads a image and predics categoryID with AI
    /// - Parameters:
    ///   - imageData: The image data.
    ///   - bodyBoundary: String to use for the boundary in the file upload.
    ///   - dataCallback: The completion handler to call when the request is completed.
    /// - Returns: A token to cancel ongoing request.
    func uploadImageAndGetCategory(
        imageData: Data,
        bodyBoundary: String?,
        dataCallback: @escaping (Response<CategoryGroup>) -> Void
    ) -> RequestToken?
}

extension Networking: PredictionClient {
    private var serviceHeader: String { "CATEGORY-PREDICTER" }
    private var baseUrl: String { environment.gatewayBaseUrl }

    @discardableResult
    public func uploadImageAndGetTips(
        imageData: Data,
        bodyBoundary: String? = nil,
        dataCallback: @escaping (Response<AdInCameraTips>) -> Void
    ) -> RequestToken? {
        perform(
            try URLRequest
                .post(
                    "\(baseUrl)/tips",
                    data: imageData,
                    fileName: "avatar.jpg",
                    mimeType: "image/jpeg",
                    multipartName: "file",
                    boundary: bodyBoundary
                )
                .preparedForGateway(withServiceHeader: serviceHeader),
                dataCallback: dataCallback
        )
    }
    
    @discardableResult
    public func uploadImageAndGetCategory(
        imageData: Data,
        bodyBoundary: String? = nil,
        dataCallback: @escaping (Response<CategoryGroup>) -> Void
    ) -> RequestToken? {
        perform(
            try URLRequest
                .post(
                    "\(baseUrl)/category",
                    data: imageData,
                    fileName: "avatar.jpg",
                    mimeType: "image/jpeg",
                    multipartName: "file",
                    boundary: bodyBoundary
                )
                .preparedForGateway(withServiceHeader: serviceHeader),
                dataCallback: dataCallback
        )
    }
}
