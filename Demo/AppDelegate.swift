//
//  Copyright (c) 2017 FINN.no AS. All rights reserved.
//

import UIKit
import Finjinon

struct FinjinonSetup: FinjinonConfiguration {
    var texts: FinjinonLocalizedTexts = Texts()

    struct Texts: FinjinonLocalizedTexts {
        var cameraAccessDenied: String {
            "finjinon.cameraAccessDenied".localized()
        }

        var done: String {
            "finjinon.done".localized()
        }

        var photos: String {
            "finjinon.photos".localized()
        }

        var on: String {
            "finjinon.on".localized()
        }

        var off: String {
            "finjinon.off".localized()
        }

        var auto: String {
            "finjinon.auto".localized()
        }

        var captureButton: String {
            "finjinon.captureButton".localized()
        }

        var lowLightMessage: String {
            "finjinon.lowLightMessage".localized()
        }
    }
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)

        Finjinon.setup(FinjinonSetup())

        window?.rootViewController = UINavigationController(rootViewController: ViewController())
        window?.makeKeyAndVisible()

        return true
    }
}
