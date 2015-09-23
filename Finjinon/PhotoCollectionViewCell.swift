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
    class func cellIdentifier() -> String { return "PhotoCell" }

    public let imageView = UIImageView(frame: CGRect.zero)
    public let closeButton: UIButton = CloseButton(frame: CGRect(x: 0, y: 0, width: 22, height: 22))
    public internal(set) var asset: Asset?

    internal weak var delegate: PhotoCollectionViewCellDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)

        let offset = self.closeButton.bounds.height/3
        imageView.frame = CGRect(x: offset, y: offset, width: contentView.bounds.width - (offset*2), height: contentView.bounds.height - (offset*2))
        imageView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        contentView.addSubview(imageView)

        closeButton.addTarget(self, action: Selector("closeButtonTapped:"), forControlEvents: .TouchUpInside)
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
}
