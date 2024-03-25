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
    
    private var messageArray: [String] = [
        "1. Ta bilde av hele produktet.",
        "2. Knips fra flere vinkler.",
        "3. Vis ekstra funksjoner."
    ]
    @Published var hintText: String?
    
    private var timer: Timer?
    
    var shouldContinue = true
    
    init() {
        self.hintText = messageArray.first ?? ""
    }
    
    func runTips() async throws {
        var index = 0 // Initialize index to start from the first element
        
        while shouldContinue {
             // Create a task that waits for a delay
             try await Task.sleep(nanoseconds: 2 * 1_000_000_000) // 2 seconds in nanoseconds
             index = (index + 1) % messageArray.count
             // Increment index and wrap around if needed, update hintText
             DispatchQueue.main.async {
                 self.hintText = self.messageArray[index]
             }
         }
    }
}


