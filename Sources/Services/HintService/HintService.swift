//
//  File.swift
//  
//
//  Created by Krister Sigvaldsen Moen on 25/03/2024.
//

import Foundation
import UIKit
import Combine
import FinniversKit

public class HintService {
    
    @Published var messageArray: [String] = [
        "Ta et bilde for å få geniale tips 📸"
    ]
    
    @Published var hintText: String?
    @Published var hasEnabledHint: Bool = false
    
    @Published var predictedCategory: CategoryGroup?
    
    @Published var itemTitle: String = ""
    
    private var timer: Timer?
    
    var shouldContinue = true
    var index = 0
    
    public var predictionClient: PredictionClient?
    
    public init() {
        
    }
    
    func runTips(_ isActive: Bool) async throws {
        self.shouldContinue = isActive
        self.hasEnabledHint = isActive
        
        self.hintText = messageArray.first ?? ""

        while shouldContinue {
            do {
                // Create a task that waits for a delay
                try await Task.sleep(nanoseconds: 3 * 1_000_000_000) // 2 seconds in nanoseconds
                index = (index + 1) % messageArray.count
                // Increment index and wrap around if needed, update hintText
                DispatchQueue.main.async {
                    self.hintText = self.messageArray[self.index]
                }
            } catch {
                self.shouldContinue = false
            }
            
            if !shouldContinue {
                self.hintText = nil
            }
         }
    }
    
    public func getItemAndTips(_ photoData: Data) {
        if hasEnabledHint {
            let boundary = UUID().uuidString
            if let imageData = UIImage(data: photoData)?.resized(withPercentage: 0.15)?.jpegData(compressionQuality: 0.8) {
                predictionClient?.uploadImageAndGetTips(imageData: imageData, bodyBoundary: boundary) { response in
                    switch response.result {
                    case .success(let response):
                        print(response)
                        self.messageArray = response.tips ?? []
                        self.itemTitle = response.item ?? ""
                        LoadingView.hide()
                        break
                    case .failure(let error):
                        print(error.localizedDescription)
                        break
                    }
                }
                
                predictionClient?.uploadImageAndGetCategory(imageData: imageData, bodyBoundary: boundary) { response in
                    switch response.result {
                    case .success(let response):
                        print(response)
                        self.predictedCategory = response
                        break
                    case .failure(let error):
                        print(error.localizedDescription)
                        break
                    }
                }
            } else {
                print("Image not found")
                return
            }
        } else {
            print("Hints is disabled")
        }
    }
}


