//
//  Copyright (c) 2019 FINN.no AS. All rights reserved.
//

import Foundation

extension String {
    func localized() -> String {
        let bundle = Bundle(for: PhotoCaptureViewController.self)
        return NSLocalizedString(self, tableName: nil, bundle: bundle, value: "", comment: "")
    }
}
