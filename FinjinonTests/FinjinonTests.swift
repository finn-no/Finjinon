//
//  FinjinonTests.swift
//  FinjinonTests
//
//  Created by Sørensen, Johan on 05.06.15.
//  Copyright (c) 2015 FINN.no AS. All rights reserved.
//

import UIKit
import XCTest
import Finjinon

class FinjinonTests: XCTestCase {

    func testViewRotateToDeviceOrientationExtension() {
        let view = UIView(frame: CGRect.zero)
        view.rotateToDeviceOrientation(.Portrait)
        let portraitTransform = view.transform
        view.rotateToDeviceOrientation(.PortraitUpsideDown)
        let portraitUpsideDownTransform = view.transform
        view.rotateToDeviceOrientation(.LandscapeLeft)
        let landscapeLeftTransform = view.transform
        view.rotateToDeviceOrientation(.LandscapeRight)
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
        view.rotateToDeviceOrientation(.Portrait)
        let unchangableTransform = view.transform
        view.rotateToDeviceOrientation(.FaceDown)
        let faceDownTransform = view.transform
        view.rotateToDeviceOrientation(.FaceUp)
        let faceUpTransform = view.transform
        XCTAssertEqual(unchangableTransform.a, faceDownTransform.a)
        XCTAssertEqual(unchangableTransform.b, faceDownTransform.b)
        XCTAssertEqual(unchangableTransform.c, faceDownTransform.c)
        XCTAssertEqual(unchangableTransform.a, faceUpTransform.a)
        XCTAssertEqual(unchangableTransform.b, faceUpTransform.b)
        XCTAssertEqual(unchangableTransform.c, faceUpTransform.c)
    }


    
}
