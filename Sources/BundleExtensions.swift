//
//  Copyright (c) 2023 FINN.no AS. All rights reserved.
//

import UIKit

extension Bundle {
    static var finjinon: Bundle {
#if SWIFT_PACKAGE
        return Bundle.module
#else
        return Bundle(for: PhotoCaptureViewController.self)
#endif
    }
}
