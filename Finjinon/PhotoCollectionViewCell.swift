//
//  PhotoCollectionViewCell.swift
//  Finjinon
//
//  Created by Sørensen, Johan on 22.06.15.
//  Copyright (c) 2015 FINN.no AS. All rights reserved.
//

import UIKit

internal protocol PhotoCollectionViewCellDelegate: NSObjectProtocol {
    func collectionViewCellDidLongPress(cell: PhotoCollectionViewCell)
    func collectionViewCellDidTapDelete(cell: PhotoCollectionViewCell)
}


internal class PhotoCollectionViewCell: UICollectionViewCell {
    weak var delegate: PhotoCollectionViewCellDelegate?
    let imageView = UIImageView(frame: CGRect.zeroRect)
    let closeButton = CloseButton(frame: CGRect(x: 0, y: 0, width: 22, height: 22))

    override init(frame: CGRect) {
        super.init(frame: frame)

        imageView.frame = bounds
        imageView.autoresizingMask = .FlexibleWidth | .FlexibleHeight
        imageView.layer.shouldRasterize = true // to avoid jaggies while we wiggle
        imageView.layer.rasterizationScale = UIScreen.mainScreen().scale
        contentView.addSubview(imageView)

        closeButton.addTarget(self, action: Selector("closeButtonTapped:"), forControlEvents: .TouchUpInside)
        closeButton.hidden = true
        contentView.addSubview(closeButton)

        let presser = UILongPressGestureRecognizer(target: self, action: Selector("longTapGestureRecognized:"))
        self.contentView.addGestureRecognizer(presser)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    internal override func prepareForReuse() {
        super.prepareForReuse()

        delegate = nil
        imageView.layer.removeAnimationForKey("jiggle")
        imageView.frame = bounds
        closeButton.hidden = true
    }

    override func hitTest(point: CGPoint, withEvent event: UIEvent?) -> UIView? {
        let delta = (44 - closeButton.bounds.width) / 2
        let expandedRect = closeButton.frame.rectByInsetting(dx: -delta, dy: -delta)
        let viewIsVisible = !closeButton.hidden && closeButton.alpha > 0.01
        if viewIsVisible && delta > 0 && expandedRect.contains(point) {
            return closeButton
        }

        return super.hitTest(point, withEvent: event)
    }

    func jiggleAndShowDeleteIcon(editing: Bool) {
        if editing {
            closeButton.alpha = 0.0
            closeButton.hidden = false
            UIView.animateWithDuration(0.23, delay: 0, options: .BeginFromCurrentState, animations: {
                self.closeButton.alpha = 1.0
                let offset = self.closeButton.bounds.height/3
                self.imageView.frame.origin.x = offset
                self.imageView.frame.origin.y = offset
                self.imageView.frame.size.height -= offset*2
                self.imageView.frame.size.width -= offset*2
                }, completion: { finished in
                    self.imageView.layer.addAnimation(self.buildJiggleAnimation(), forKey: "jiggle")
            })
        } else {
            self.imageView.layer.removeAnimationForKey("jiggle")
            UIView.animateWithDuration(0.23, delay: 0, options: .BeginFromCurrentState, animations: {
                self.imageView.frame = self.contentView.bounds
                self.closeButton.alpha = 0.0
                }, completion: { finished in
                    self.closeButton.hidden = true
            })
        }
    }

    func longTapGestureRecognized(recognizer: UILongPressGestureRecognizer) {
        if recognizer.state == .Began {
            delegate?.collectionViewCellDidLongPress(self)
        }
    }

    func closeButtonTapped(sender: UIButton) {
        delegate?.collectionViewCellDidTapDelete(self)
    }

    private func buildJiggleAnimation() -> CABasicAnimation {
        let animation  = CABasicAnimation(keyPath: "transform.rotation")
        let startAngle = (-1) * M_PI/180.0;
        animation.fromValue = startAngle
        animation.toValue = 2 * -startAngle
        animation.autoreverses = true
        animation.repeatCount = Float.infinity
        let duration = 0.1
        animation.duration = duration
        animation.timeOffset = Double((arc4random() % 100) / 100) - duration
        return animation
    }
}
