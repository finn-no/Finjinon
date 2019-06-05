//
//  Copyright (c) 2019 FINN.no AS. All rights reserved.
//

import UIKit

class TriggerButton: UIButton {
    var buttonColor = UIColor.white {
        didSet {
            setNeedsDisplay()
        }
    }

    override var isEnabled: Bool {
        didSet {
            setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = UIColor.clear
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        let length = min(bounds.width, bounds.height)
        let outerRect = CGRect(x: (bounds.width / 2) - (length / 2), y: (bounds.height / 2) - (length / 2), width: length, height: length)
        let borderWidth: CGFloat = 6.0
        let outerPath = UIBezierPath(ovalIn: outerRect.insetBy(dx: borderWidth, dy: borderWidth))
        outerPath.lineWidth = borderWidth

        buttonColor.setStroke()
        outerPath.stroke()

        let innerPath = UIBezierPath(ovalIn: outerRect.insetBy(dx: borderWidth + 5, dy: borderWidth + 5))
        if isEnabled {
            buttonColor.setFill()
        } else {
            UIColor.gray.setFill()
        }
        innerPath.fill()
    }
}
