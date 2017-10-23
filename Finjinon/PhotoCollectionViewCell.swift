//
//  Copyright (c) 2017 FINN.no AS. All rights reserved.
//

import UIKit

internal protocol PhotoCollectionViewCellDelegate: NSObjectProtocol {
    func collectionViewCellDidTapDelete(_ cell: PhotoCollectionViewCell)
}


open class PhotoCollectionViewCell: UICollectionViewCell {
    open class func cellIdentifier() -> String { return "PhotoCell" }

    open let imageView = UIImageView(frame: CGRect.zero)
    open let closeButton: UIButton = CloseButton(frame: CGRect(x: 0, y: 0, width: 22, height: 22))
    open internal(set) var asset: Asset?

    internal weak var delegate: PhotoCollectionViewCellDelegate?

    public override init(frame: CGRect) {
        super.init(frame: frame)

        let offset = self.closeButton.bounds.height/3
        imageView.frame = CGRect(x: offset, y: offset, width: contentView.bounds.width - (offset*2), height: contentView.bounds.height - (offset*2))
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)

        closeButton.addTarget(self, action: #selector(closeButtonTapped(_:)), for: .touchUpInside)
        contentView.addSubview(closeButton)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override func prepareForReuse() {
        super.prepareForReuse()

        delegate = nil
        asset = nil
    }

    internal func closeButtonTapped(_ sender: UIButton) {
        delegate?.collectionViewCellDidTapDelete(self)
    }

    internal func proxy() -> UIView {
        var wrapperFrame = self.imageView.bounds
        wrapperFrame.origin.x = (bounds.size.width - wrapperFrame.size.width)/2
        wrapperFrame.origin.y = (bounds.size.height - wrapperFrame.size.height)/2

        let imageWrapper = UIView(frame: wrapperFrame)
        imageWrapper.clipsToBounds = true
        let image = UIImage(cgImage: self.imageView.image!.cgImage!, scale: self.imageView.image!.scale, orientation: self.imageView.image!.imageOrientation)

        // Cumbersome indeed, but unfortunately re-rendering through begin graphicContext etc. fails quite often in iOS9
        var imageRect : CGRect {
            let viewSize = self.imageView.frame.size

            let imageIsLandscape = image.size.width > image.size.height
            if imageIsLandscape {
                let ratio = image.size.height / viewSize.height
                let width = image.size.width / ratio
                let x = -(width - viewSize.width)/2
                return CGRect(x: x, y: 0, width: width, height: viewSize.height)
            } else {
                let ratio = image.size.width / viewSize.width
                let height = image.size.height / ratio
                let y = -(height - viewSize.height)/2
                return CGRect(x: 0, y: y, width: viewSize.width, height: height)
            }
        }
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.frame = imageRect

        imageWrapper.addSubview(imageView)
        imageWrapper.transform = contentView.transform

        return imageWrapper
    }
}
