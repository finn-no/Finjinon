//
//  File.swift
//  
//
//  Created by Krister Sigvaldsen Moen on 25/03/2024.
//

import Foundation
import UIKit
import Combine

class HintService {
    
    @Published var messageArray: [String] = [
        "Ta bilde av hele produktet.",
        "Knips fra flere vinkler.",
        "Vis ekstra funksjoner."
    ]
    
    @Published var hintText: String?
    @Published var hasEnabledHint: Bool = false
    
    private var timer: Timer?
    
    var shouldContinue = true
    var index = 0
    
    var predictionClient: PredictionClient?
    
    init() {
        
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
    
    func getItemAndTips(_ photoData: Data) {
        if hasEnabledHint {
            let boundary = UUID().uuidString
            if let imageData = UIImage(data: photoData)?.resized(withPercentage: 0.15)?.jpegData(compressionQuality: 0.8) {
                predictionClient?.uploadImageAndGetTips(imageData: imageData, bodyBoundary: boundary) { response in
                    switch response.result {
                    case .success(let response):
                        print(response)
                        self.messageArray = response.tips ?? []
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


