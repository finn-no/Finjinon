//
//  PhotoCollectionViewLayout.swift
//  Finjinon
//
//  Created by Sørensen, Johan on 22.06.15.
//  Copyright (c) 2015 FINN.no AS. All rights reserved.
//

import UIKit

private class DraggingProxy: UIImageView {
    var fromIndexPath: NSIndexPath?
    var fromCenter = CGPoint.zeroPoint

    init(cell: UICollectionViewCell) {
        super.init(frame: CGRect.zeroRect)

        UIGraphicsBeginImageContextWithOptions(cell.bounds.size, false, 0)
        cell.drawViewHierarchyInRect(cell.bounds, afterScreenUpdates: true)
        let cellImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        image = cellImage
        frame = CGRect(x: 0, y: 0, width: cell.bounds.width, height: cell.bounds.height)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

internal class PhotoCollectionViewLayout: UICollectionViewFlowLayout, UIGestureRecognizerDelegate {
    private var insertedIndexPaths: [NSIndexPath] = []
    private var longPressGestureRecognizer: UILongPressGestureRecognizer!
    private var panGestureRecgonizer: UIPanGestureRecognizer!
    private var dragProxy: DraggingProxy?

    override init() {
        super.init()
        self.addObserver(self, forKeyPath: "collectionView", options: nil, context: nil)
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.addObserver(self, forKeyPath: "collectionView", options: nil, context: nil)
    }

    deinit {
        self.removeObserver(self, forKeyPath: "collectionView", context: nil)
    }

    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if keyPath == "collectionView" {
            setupGestureRecognizers()
        } else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }

    // MARK: - UICollectionView

    override func prepareForCollectionViewUpdates(updateItems: [AnyObject]!) {
        super.prepareForCollectionViewUpdates(updateItems)

        insertedIndexPaths.removeAll(keepCapacity: true)

        for update in updateItems as! [UICollectionViewUpdateItem] {
            switch update.updateAction {
            case .Insert:
                insertedIndexPaths.append(update.indexPathAfterUpdate!)
            default:
                return
            }
        }
    }

    override func initialLayoutAttributesForAppearingItemAtIndexPath(itemIndexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
        let attrs = super.initialLayoutAttributesForAppearingItemAtIndexPath(itemIndexPath)

        if contains(insertedIndexPaths, itemIndexPath) {
            if let attrs = attrs {
                let transform = CATransform3DTranslate(attrs.transform3D, attrs.frame.midX - self.collectionView!.frame.midX, attrs.frame.midY - self.collectionView!.frame.midY, 0)
                attrs.transform3D = CATransform3DScale(transform, 0.001, 0.001, 1)
            }
        }
        
        return attrs
    }



    override func layoutAttributesForElementsInRect(rect: CGRect) -> [AnyObject]? {
        if let attributes = super.layoutAttributesForElementsInRect(rect) as? [UICollectionViewLayoutAttributes] {
            for layoutAttribute in attributes {
                if layoutAttribute.representedElementCategory != .Cell {
                    continue
                }

                if layoutAttribute.indexPath == dragProxy?.fromIndexPath {
                    layoutAttribute.alpha = 0.0 // hide the sourceCell, the drag proxy now represents it
                }
            }

            return attributes
        }
        return nil
    }

    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == longPressGestureRecognizer {
            if otherGestureRecognizer == panGestureRecgonizer {
                return true
            }
        } else if gestureRecognizer == panGestureRecgonizer {
            if otherGestureRecognizer == longPressGestureRecognizer {
                return true
            } else {
                return false
            }
        } else if gestureRecognizer == self.collectionView?.panGestureRecognizer {
            if (longPressGestureRecognizer.state != .Possible || longPressGestureRecognizer.state != .Failed) {
                return false
            }
        }

        return true
    }

    // MARK: -  Private methods

    func handleLongPressGestureRecognized(recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .Began:
            NSLog("[DRAGGING] longpress .Began")
            let location = recognizer.locationInView(collectionView)
            if let indexPath = collectionView!.indexPathForItemAtPoint(location), let cell = collectionView!.cellForItemAtIndexPath(indexPath) {
                let proxy = DraggingProxy(cell: cell)
                proxy.layer.borderColor = UIColor.redColor().CGColor
                proxy.layer.borderWidth = 1.0
                proxy.fromIndexPath = indexPath
                if let cell = collectionView?.cellForItemAtIndexPath(indexPath) {
                    proxy.frame = cell.bounds
                    proxy.fromCenter = cell.center
                } else {
                    proxy.fromCenter = location
                }
                proxy.center = proxy.fromCenter
                dragProxy = proxy
                collectionView?.addSubview(proxy)

                invalidateLayout()

                // TODO: animate the proxy
            } else {
                NSLog("[DRAGGING] no indexPath for loc \(location)")
            }
        case .Ended:
            if let proxy = self.dragProxy {
                UIView.animateWithDuration(0.2, delay: 0.0, options: .BeginFromCurrentState | .CurveEaseIn, animations: {
                    proxy.center = proxy.fromCenter
                }, completion: { finished in
                    proxy.removeFromSuperview()
                    self.dragProxy = nil

                    self.invalidateLayout()
                })
            }
        default:
            break
        }
    }

    func handlePanGestureRecognized(recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translationInView(collectionView!)
        switch recognizer.state {
        case .Changed:
            NSLog("[DRAGGING] pangesture .Changed translation=\(translation)")
            if let proxy = dragProxy {
                proxy.center.x = proxy.fromCenter.x + translation.x
                //TODO: Constrain to be within collectionView.frame:
                // proxy.center.y = proxy.fromCenter.y + translation.y
            }
        default:
            break
        }
    }

    private func setupGestureRecognizers() {
        if let collectionView = self.collectionView {
            NSLog("[DRAGGING] Adding gesture recognizers")
            longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: Selector("handleLongPressGestureRecognized:"))
            longPressGestureRecognizer.delegate = self

            panGestureRecgonizer = UIPanGestureRecognizer(target: self, action: Selector("handlePanGestureRecognized:"))
            panGestureRecgonizer.delegate = self
            panGestureRecgonizer.maximumNumberOfTouches = 1

            collectionView.panGestureRecognizer.requireGestureRecognizerToFail(longPressGestureRecognizer)

            collectionView.addGestureRecognizer(longPressGestureRecognizer)
            collectionView.addGestureRecognizer(panGestureRecgonizer)
        }
    }
}
