//
//  UIImage.swift Extensions
//
//
//  Created by Krister Sigvaldsen Moen on 26/03/2024.
//

import Foundation
import UIKit

extension UIImage {
    func resized(withPercentage percentage: CGFloat, isOpaque: Bool = true) -> UIImage? {
          let canvas = CGSize(width: size.width * percentage, height: size.height * percentage)
          let format = imageRendererFormat
          format.opaque = isOpaque
          return UIGraphicsImageRenderer(size: canvas, format: format).image {
              _ in draw(in: CGRect(origin: .zero, size: canvas))
          }
      }
}
