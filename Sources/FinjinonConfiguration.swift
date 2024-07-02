//
//  Copyright (c) 2024 FINN.no AS. All rights reserved.
//

import Foundation

public protocol FinjinonConfiguration {
    var texts: FinjinonLocalizedTexts { get }
}

public protocol FinjinonLocalizedTexts {
    var cameraAccessDenied: String { get }
    var done: String { get }
    var photos: String { get }
    var on: String { get }
    var off: String { get }
    var auto: String { get }
    var captureButton: String { get }
    var lowLightMessage: String { get }
}
