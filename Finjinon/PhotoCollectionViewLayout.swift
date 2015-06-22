//
//  PhotoCollectionViewLayout.swift
//  Finjinon
//
//  Created by Sørensen, Johan on 22.06.15.
//  Copyright (c) 2015 FINN.no AS. All rights reserved.
//

import UIKit

internal class PhotoCollectionViewLayout: UICollectionViewFlowLayout {
    var insertedIndexPaths: [NSIndexPath] = []

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
}
