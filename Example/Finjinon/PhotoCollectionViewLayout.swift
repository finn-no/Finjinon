//
//  Copyright (c) 2017 FINN.no AS. All rights reserved.
//

import UIKit

private class DraggingProxy: UIView {
    var dragIndexPath: IndexPath? // Current indexPath
    var dragCenter = CGPoint.zero // point being dragged from
    var fromIndexPath: IndexPath? // Original index path
    var toIndexPath: IndexPath? // index path the proxy was dragged to
    var initialCenter = CGPoint.zero

    init(cell: PhotoCollectionViewCell) {
        super.init(frame: CGRect.zero)

        backgroundColor = UIColor.clear
        autoresizingMask = cell.autoresizingMask
        clipsToBounds = true
        frame = CGRect(x: 0, y: 0, width: cell.bounds.width, height: cell.bounds.height)

        let proxyView = cell.proxy()
        addSubview(proxyView)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public protocol PhotoCollectionViewLayoutDelegate: NSObjectProtocol {
    func photoCollectionViewLayout(_ layout: UICollectionViewLayout, canMoveItemAtIndexPath indexPath: IndexPath) -> Bool
}

class PhotoCollectionViewLayout: UICollectionViewFlowLayout, UIGestureRecognizerDelegate {
    var didReorderHandler: (_ fromIndexPath: IndexPath, _ toIndexPath: IndexPath) -> Void = { _, _ in }
    fileprivate var insertedIndexPaths: [IndexPath] = []
    fileprivate var deletedIndexPaths: [IndexPath] = []
    fileprivate var longPressGestureRecognizer = UILongPressGestureRecognizer()
    fileprivate var panGestureRecognizer = UIPanGestureRecognizer()
    fileprivate var dragProxy: DraggingProxy?
    weak var delegate: PhotoCollectionViewLayoutDelegate?

    override init() {
        super.init()
        addObserver(self, forKeyPath: "collectionView", options: [], context: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        addObserver(self, forKeyPath: "collectionView", options: [], context: nil)
    }

    deinit {
        self.removeObserver(self, forKeyPath: "collectionView", context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "collectionView" {
            setupGestureRecognizers()
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    // MARK: - UICollectionView

    override func prepare(forCollectionViewUpdates updateItems: [UICollectionViewUpdateItem]) {
        super.prepare(forCollectionViewUpdates: updateItems)

        insertedIndexPaths.removeAll(keepingCapacity: false)
        deletedIndexPaths.removeAll(keepingCapacity: false)

        for update in updateItems {
            switch update.updateAction {
            case .insert:
                insertedIndexPaths.append(update.indexPathAfterUpdate!)
            case .delete:
                deletedIndexPaths.append(update.indexPathBeforeUpdate!)
            default:
                return
            }
        }
    }

    override func finalizeCollectionViewUpdates() {
        super.finalizeCollectionViewUpdates()

        insertedIndexPaths.removeAll(keepingCapacity: false)
        deletedIndexPaths.removeAll(keepingCapacity: false)
    }

    override func initialLayoutAttributesForAppearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        let attrs = super.initialLayoutAttributesForAppearingItem(at: itemIndexPath)

        if insertedIndexPaths.contains(itemIndexPath) {
            // only change attributes on inserted cells
            if let attrs = attrs {
                attrs.alpha = 0.0
                attrs.zIndex = itemIndexPath.item
                attrs.center.x = collectionView!.frame.width / 2
                attrs.center.y = collectionView!.frame.height
                if collectionView!.contentOffset.x > 0.0 {
                    attrs.center.x += collectionView!.contentOffset.x
                }
                attrs.transform3D = CATransform3DScale(attrs.transform3D, 0.001, 0.001, 1)
            }
        }

        return attrs
    }

    override func finalLayoutAttributesForDisappearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        let attrs = super.finalLayoutAttributesForDisappearingItem(at: itemIndexPath)

        if deletedIndexPaths.contains(itemIndexPath) {
            if let attrs = attrs {
                attrs.alpha = 0.0
                attrs.center.x = collectionView!.frame.width / 2
                attrs.center.y = collectionView!.frame.height
                if collectionView!.contentOffset.x > 0.0 {
                    attrs.center.x += collectionView!.contentOffset.x
                }
                attrs.transform3D = CATransform3DScale(attrs.transform3D, 0.001, 0.001, 1)
            }
        }

        return attrs
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        if let attributes = super.layoutAttributesForElements(in: rect) {
            for layoutAttribute in attributes {
                if layoutAttribute.representedElementCategory != .cell {
                    continue
                }

                if layoutAttribute.indexPath == dragProxy?.dragIndexPath {
                    layoutAttribute.alpha = 0.0 // hide the sourceCell, the drag proxy now represents it
                }
            }

            return attributes
        }
        return nil
    }

    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == longPressGestureRecognizer && otherGestureRecognizer == panGestureRecognizer {
            return true
        } else if gestureRecognizer == panGestureRecognizer {
            return otherGestureRecognizer == longPressGestureRecognizer
        }

        return true
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        func canMoveItemAtIndexPath(_ indexPath: IndexPath) -> Bool {
            return delegate?.photoCollectionViewLayout(self, canMoveItemAtIndexPath: indexPath) ?? true
        }

        if gestureRecognizer == longPressGestureRecognizer {
            let location = gestureRecognizer.location(in: collectionView)
            if let indexPath = collectionView?.indexPathForItem(at: location), !canMoveItemAtIndexPath(indexPath) {
                return false
            }
        }

        let states: [UIGestureRecognizerState] = [.possible, .failed]
        if gestureRecognizer == longPressGestureRecognizer && !states.contains(collectionView!.panGestureRecognizer.state) {
            return false
        } else if gestureRecognizer == panGestureRecognizer && states.contains(longPressGestureRecognizer.state) {
            return false
        }

        return true
    }

    // MARK: -  Private methods

    @objc func handleLongPressGestureRecognized(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            let location = recognizer.location(in: collectionView)
            if let indexPath = collectionView!.indexPathForItem(at: location), let cell = collectionView!.cellForItem(at: indexPath) {
                dragProxy?.removeFromSuperview()
                let proxy = DraggingProxy(cell: cell as! PhotoCollectionViewCell)
                proxy.dragIndexPath = indexPath
                proxy.initialCenter = cell.center
                proxy.dragCenter = cell.center
                proxy.center = proxy.dragCenter

                proxy.fromIndexPath = indexPath

                dragProxy = proxy
                collectionView?.addSubview(dragProxy!)

                invalidateLayout()

                UIView.animate(withDuration: 0.16, animations: {
                    self.dragProxy?.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                })
            }
        case .ended:
            if let proxy = self.dragProxy {
                UIView.animate(withDuration: 0.2, delay: 0.0, options: [.beginFromCurrentState, .curveEaseIn], animations: {
                    proxy.center = proxy.dragCenter
                    proxy.transform = CGAffineTransform.identity
                }, completion: { _ in
                    proxy.removeFromSuperview()

                    if let fromIndexPath = proxy.fromIndexPath, let toIndexPath = proxy.toIndexPath {
                        self.didReorderHandler(fromIndexPath, toIndexPath)
                    }

                    self.dragProxy = nil

                    self.invalidateLayout()
                })
            }
        default:
            break
        }
    }

    @objc func handlePanGestureRecognized(_ recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: collectionView!)
        switch recognizer.state {
        case .changed:
            if let proxy = dragProxy {
                proxy.center.x = proxy.initialCenter.x + translation.x

                if let fromIndexPath = proxy.dragIndexPath,
                    let toIndexPath = collectionView!.indexPathForItem(at: proxy.center),
                    let targetLayoutAttributes = layoutAttributesForItem(at: toIndexPath) {
                    proxy.dragIndexPath = toIndexPath
                    proxy.dragCenter = targetLayoutAttributes.center
                    proxy.bounds = targetLayoutAttributes.bounds
                    proxy.toIndexPath = toIndexPath

                    collectionView?.performBatchUpdates({
                        self.collectionView?.moveItem(at: fromIndexPath, to: toIndexPath)
                    }, completion: nil
                    )
                }
            }
        default:
            break
        }
    }

    fileprivate func setupGestureRecognizers() {
        if let _ = self.collectionView {
            // Because iOS9 calls this twice, and it will be called again if we change the collectionView.layout anyways
            collectionView!.removeGestureRecognizer(longPressGestureRecognizer)
            collectionView!.removeGestureRecognizer(panGestureRecognizer)

            longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGestureRecognized(_:)))
            longPressGestureRecognizer.delegate = self
            collectionView!.addGestureRecognizer(longPressGestureRecognizer)

            panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGestureRecognized(_:)))
            panGestureRecognizer.delegate = self
            panGestureRecognizer.maximumNumberOfTouches = 1
            collectionView!.addGestureRecognizer(panGestureRecognizer)
        }
    }
}
