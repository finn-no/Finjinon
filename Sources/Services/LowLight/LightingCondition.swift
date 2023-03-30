//
//  Copyright (c) 2019 FINN.no AS. All rights reserved.
//
import Foundation

enum LightingCondition: String {
    case low
    case normal
    case high

    init(value: Double) {
        switch Int(round(value)) {
        case Int.min..<3:
            self = .low
        case 14...Int.max:
            self = .high
        default:
            self = .normal
        }
    }
}
