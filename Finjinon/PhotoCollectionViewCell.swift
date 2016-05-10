//
//  PhotoCollectionViewCell.swift
//  Finjinon
//
//  Created by Sørensen, Johan on 22.06.15.
//  Copyright (c) 2015 FINN.no AS. All rights reserved.
//

import UIKit

internal protocol PhotoCollectionViewCellDelegate: NSObjectProtocol {
    func collectionViewCellDidTapDelete(cell: PhotoCollectionViewCell)
}


public class PhotoCollectionViewCell: UICollectionViewCell {
    public class func cellIdentifier() -> String { return "PhotoCell" }

    public let imageView = UIImageView(frame: CGRect.zero)
    public let closeButton: UIButton = CloseButton(frame: CGRect(x: 0, y: 0, width: 22, height: 22))
    public internal(set) var asset: Asset?

    internal weak var delegate: PhotoCollectionViewCellDelegate?

    public override init(frame: CGRect) {
        super.init(frame: frame)

        let offset = self.closeButton.bounds.height/3
        imageView.frame = CGRect(x: offset, y: offset, width: contentView.bounds.width - (offset*2), height: contentView.bounds.height - (offset*2))
        imageView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        imageView.contentMode = .ScaleAspectFill
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)

        closeButton.addTarget(self, action: #selector(closeButtonTapped(_:)), forControlEvents: .TouchUpInside)
        contentView.addSubview(closeButton)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func prepareForReuse() {
        super.prepareForReuse()

        delegate = nil
        asset = nil
    }

    internal func closeButtonTapped(sender: UIButton) {
        delegate?.collectionViewCellDidTapDelete(self)
    }

    internal func proxy() -> UIView {
        var wrapperFrame = self.imageView.bounds
        wrapperFrame.origin.x = (bounds.size.width - wrapperFrame.size.width)/2
        wrapperFrame.origin.y = (bounds.size.height - wrapperFrame.size.height)/2

        let imageWrapper = UIView(frame: wrapperFrame)
        imageWrapper.clipsToBounds = true
        let image = UIImage(CGImage: self.imageView.image!.CGImage!, scale: self.imageView.image!.scale, orientation: self.imageView.image!.imageOrientation)

        // Cumbersome indeed, but unfortunately re-rendering through begin graphicContext etc. fails quite often in iOS9
        var imageRect : CGRect {
            let viewSize = self.imageView.frame.size

            let imageIsLandscape = image.size.width > image.size.height
            if imageIsLandscape {
                let ratio = image.size.height / viewSize.height
                let width = image.size.width / ratio
                let x = -(width - viewSize.width)/2
                return CGRectMake(x, 0, width, viewSize.height)
            } else {
                let ratio = image.size.width / viewSize.width
                let height = image.size.height / ratio
                let y = -(height - viewSize.height)/2
                return CGRectMake(0, y, viewSize.width, height)
            }
        }
        let imageView = UIImageView(image: image)
        imageView.contentMode = .ScaleAspectFill
        imageView.clipsToBounds = true
        imageView.frame = imageRect

        imageWrapper.addSubview(imageView)
        imageWrapper.transform = contentView.transform

        return imageWrapper
    }
}
