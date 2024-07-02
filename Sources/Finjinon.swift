//
//  Copyright (c) 2024 FINN.no AS. All rights reserved.
//

import Foundation

public struct Finjinon {
    static var configuration: FinjinonConfiguration!

    /// Required setup to be able to use Finjinon
    public static func setup(_ configuration: FinjinonConfiguration) {
        self.configuration = configuration
    }
}
