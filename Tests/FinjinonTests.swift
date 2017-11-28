//
//  Copyright (c) 2017 FINN.no AS. All rights reserved.
//

import UIKit
import XCTest
import Finjinon

class FinjinonTests: XCTestCase {

    func testViewRotateToDeviceOrientationExtension() {
        let view = UIView(frame: CGRect.zero)
        view.rotateToDeviceOrientation(.portrait)
        let portraitTransform = view.transform
        view.rotateToDeviceOrientation(.portraitUpsideDown)
        let portraitUpsideDownTransform = view.transform
        view.rotateToDeviceOrientation(.landscapeLeft)
        let landscapeLeftTransform = view.transform
        view.rotateToDeviceOrientation(.landscapeRight)
        let landscapRightTransform = view.transform

        // portrait vs. portraitUpsideDown
        XCTAssertEqual(portraitTransform.a, portraitUpsideDownTransform.a)
        XCTAssertEqual(portraitTransform.b, portraitUpsideDownTransform.b)
        XCTAssertEqual(portraitTransform.c, portraitUpsideDownTransform.c)

        // portrait vs. landscape
        XCTAssertNotEqual(portraitTransform.a, landscapeLeftTransform.a)
        XCTAssertNotEqual(portraitTransform.b, landscapeLeftTransform.b)
        XCTAssertNotEqual(portraitTransform.c, landscapeLeftTransform.c)
        XCTAssertNotEqual(portraitUpsideDownTransform.a, landscapeLeftTransform.a)
        XCTAssertNotEqual(portraitUpsideDownTransform.b, landscapeLeftTransform.b)
        XCTAssertNotEqual(portraitUpsideDownTransform.c, landscapeLeftTransform.c)
        XCTAssertNotEqual(portraitTransform.a, landscapRightTransform.a)
        XCTAssertNotEqual(portraitTransform.b, landscapRightTransform.b)
        XCTAssertNotEqual(portraitTransform.c, landscapRightTransform.c)
        XCTAssertNotEqual(portraitUpsideDownTransform.a, landscapRightTransform.a)
        XCTAssertNotEqual(portraitUpsideDownTransform.b, landscapRightTransform.b)
        XCTAssertNotEqual(portraitUpsideDownTransform.c, landscapRightTransform.c)

        // landscapeLeft vs. landscapeRight
        XCTAssertEqual(landscapRightTransform.a, landscapeLeftTransform.a)
        XCTAssertNotEqual(landscapRightTransform.b, landscapeLeftTransform.b)
        XCTAssertNotEqual(landscapRightTransform.c, landscapeLeftTransform.c)

        // Test that .FaceUp & .FaceDown does not trigger any changes.
        view.rotateToDeviceOrientation(.portrait)
        let unchangeableTransform = view.transform
        view.rotateToDeviceOrientation(.faceDown)
        let faceDownTransform = view.transform
        view.rotateToDeviceOrientation(.faceUp)
        let faceUpTransform = view.transform
        XCTAssertEqual(unchangeableTransform.a, faceDownTransform.a)
        XCTAssertEqual(unchangeableTransform.b, faceDownTransform.b)
        XCTAssertEqual(unchangeableTransform.c, faceDownTransform.c)
        XCTAssertEqual(unchangeableTransform.a, faceUpTransform.a)
        XCTAssertEqual(unchangeableTransform.b, faceUpTransform.b)
        XCTAssertEqual(unchangeableTransform.c, faceUpTransform.c)
    }
}
