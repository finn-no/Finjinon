//
//  TriggerButton.swift
//  Finjinon
//
//  Created by Sørensen, Johan on 18.06.15.
//  Copyright (c) 2015 FINN.no AS. All rights reserved.
//

import UIKit

class TriggerButton: UIButton {
    var buttonColor = UIColor.whiteColor() {
        didSet {
            setNeedsDisplay()
        }
    }
    override var enabled: Bool {
        didSet {
            setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = UIColor.clearColor()
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawRect(dirtyRect: CGRect) {
        super.drawRect(dirtyRect)

        let length = min(bounds.width, bounds.height)
        let outerRect = CGRect(x: (bounds.width/2)-(length/2), y: (bounds.height/2)-(length/2), width: length, height: length)
        let borderWidth: CGFloat = 6.0
        let outerPath = UIBezierPath(ovalInRect: outerRect.rectByInsetting(dx: borderWidth, dy: borderWidth))
        outerPath.lineWidth = borderWidth

        buttonColor.setStroke()
        outerPath.stroke()

        let innerPath = UIBezierPath(ovalInRect: outerRect.rectByInsetting(dx: borderWidth + 5, dy: borderWidth + 5))
        if enabled {
            buttonColor.setFill()
        } else {
            UIColor.grayColor().setFill()
        }
        innerPath.fill()
    }
}


class CloseButton: UIButton {
    var strokeColor = UIColor.darkGrayColor() {
        didSet { setNeedsDisplay() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = UIColor.lightGrayColor().colorWithAlphaComponent(0.8)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        layer.cornerRadius = bounds.height/2
        layer.masksToBounds = true
    }

    override func drawRect(dirtyRect: CGRect) {
        super.drawRect(dirtyRect)

        // Draw a +
        let centerPoint = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius: CGFloat = bounds.rectByInsetting(dx: floor(bounds.width/8), dy: floor(bounds.width/8)).width / 2
        let ratio: CGFloat = 0.5
        let xPath = UIBezierPath()
        xPath.moveToPoint(centerPoint)
        xPath.addLineToPoint(CGPoint(x: centerPoint.x, y: centerPoint.y + (radius * ratio)))
        xPath.moveToPoint(centerPoint)
        xPath.addLineToPoint(CGPoint(x: centerPoint.x, y: centerPoint.y - (radius * ratio)))
        xPath.moveToPoint(centerPoint)
        xPath.addLineToPoint(CGPoint(x: centerPoint.x + (radius * ratio), y: centerPoint.y))
        xPath.moveToPoint(centerPoint)
        xPath.addLineToPoint(CGPoint(x: centerPoint.x - (radius * ratio), y: centerPoint.y))
        xPath.moveToPoint(centerPoint)
        xPath.closePath()

        // Rotate path by 45° around its center
        let pathBounds = CGPathGetBoundingBox(xPath.CGPath)
        xPath.applyTransform(CGAffineTransformMakeTranslation(-pathBounds.midX, -pathBounds.midY))
        xPath.applyTransform(CGAffineTransformMakeRotation(CGFloat(45.0 * M_PI / 180.0)))
        xPath.applyTransform(CGAffineTransformMakeTranslation(pathBounds.midX, pathBounds.midY))

        xPath.lineWidth = 2
        xPath.lineCapStyle = kCGLineCapRound
        strokeColor.setStroke()

        xPath.stroke()
    }
}
