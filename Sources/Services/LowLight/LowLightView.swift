//
//  Copyright (c) 2019 FINN.no AS. All rights reserved.
//

import UIKit

final class LowLightView: UIView {
    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(
            named: "LowLightIcon",
            in: Bundle.finjinon,
            compatibleWith: nil
        )
        return imageView
    }()

    private lazy var textLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.numberOfLines = 0
        return label
    }()

    var text: String? {
        get { return textLabel.text }
        set { textLabel.text = newValue }
    }

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    // MARK: - Setup

    private func setup() {
        backgroundColor = UIColor.black.withAlphaComponent(0.8)
        layer.cornerRadius = 8

        addSubview(iconImageView)
        addSubview(textLabel)

        let spacing: CGFloat = 8

        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: spacing),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),

            textLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: spacing),
            textLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -spacing),
            textLabel.topAnchor.constraint(equalTo: topAnchor, constant: spacing),
            textLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -spacing)
        ])
    }
}
