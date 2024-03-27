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

public protocol PredictionClient: AnyObject {
    @discardableResult
    /// Uploads a image and predics categoryID with AI
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
                    baseUrl,
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
