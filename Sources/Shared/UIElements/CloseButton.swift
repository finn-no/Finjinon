//
//  Copyright © 2019 FINN.no. All rights reserved.
//

import UIKit

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
