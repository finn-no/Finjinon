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
