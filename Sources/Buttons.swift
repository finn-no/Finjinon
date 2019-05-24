//
//  Copyright (c) 2017 FINN.no AS. All rights reserved.
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

class CloseButton: UIButton {
    var strokeColor = UIColor.black {
        didSet { setNeedsDisplay() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = UIColor.lightGray.withAlphaComponent(0.9)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        layer.cornerRadius = bounds.height / 2
        layer.masksToBounds = true
    }

    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        // Draw a +
        let centerPoint = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius: CGFloat = bounds.insetBy(dx: floor(bounds.width / 8), dy: floor(bounds.width / 8)).width / 2
        let ratio: CGFloat = 0.5
        let xPath = UIBezierPath()
        xPath.move(to: centerPoint)
        xPath.addLine(to: CGPoint(x: centerPoint.x, y: centerPoint.y + (radius * ratio)))
        xPath.move(to: centerPoint)
        xPath.addLine(to: CGPoint(x: centerPoint.x, y: centerPoint.y - (radius * ratio)))
        xPath.move(to: centerPoint)
        xPath.addLine(to: CGPoint(x: centerPoint.x + (radius * ratio), y: centerPoint.y))
        xPath.move(to: centerPoint)
        xPath.addLine(to: CGPoint(x: centerPoint.x - (radius * ratio), y: centerPoint.y))
        xPath.move(to: centerPoint)
        xPath.close()

        // Rotate path by 45° around its center
        let pathBounds = xPath.cgPath.boundingBox
        xPath.apply(CGAffineTransform(translationX: -pathBounds.midX, y: -pathBounds.midY))
        xPath.apply(CGAffineTransform(rotationAngle: CGFloat(45.0 * Double.pi / 180.0)))
        xPath.apply(CGAffineTransform(translationX: pathBounds.midX, y: pathBounds.midY))

        xPath.lineWidth = 2
        xPath.lineCapStyle = CGLineCap.round
        strokeColor.setStroke()

        xPath.stroke()
    }
}
