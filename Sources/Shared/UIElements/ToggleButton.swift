//
//  ToggleButton.swift
//
//  Created by Krister Sigvaldsen Moen on 27/03/2024.
//

import Foundation
import UIKit

class ToggleButton: UIButton {
    
    var buttonColor = UIColor.black.withAlphaComponent(0.5) {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var strokeColor = UIColor.white.withAlphaComponent(0.5) {
        didSet {
            setNeedsDisplay()
        }
    }

    override var isEnabled: Bool {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var isActive: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let image = UIImage(named: "aiSparkles", in: Bundle.finjinon, compatibleWith: nil)
        image?.withRenderingMode(.alwaysTemplate)
        imageView?.contentMode = .scaleAspectFit
        setImage(image, for: .normal)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func toggleState() -> Bool {
        self.isActive.toggle()
        
        self.buttonColor = self.isActive ? UIColor.black.withAlphaComponent(0.7) : UIColor.black.withAlphaComponent(0.5)
        self.strokeColor = self.isActive ? .purple : UIColor.white.withAlphaComponent(0.5)
        
        return self.isActive
    }
    
    
    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        let length = min(bounds.width, bounds.height)
        let outerRect = CGRect(x: (bounds.width / 2) - (length / 2), y: (bounds.height / 2) - (length / 2), width: length, height: length)
        let borderWidth: CGFloat = 6.0
        
        let outerPath = UIBezierPath(ovalIn: outerRect.insetBy(dx: borderWidth, dy: borderWidth))
        
        outerPath.lineWidth = borderWidth

        strokeColor.setStroke()
        outerPath.stroke()

        let innerPath = UIBezierPath(ovalIn: outerRect.insetBy(dx: borderWidth + 5, dy: borderWidth + 5))
        
        if isEnabled {
            buttonColor.setFill()
        } else {
           UIColor.black.withAlphaComponent(0.5).setFill()
        }
        
        innerPath.fill()
    }
}
