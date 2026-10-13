import CoreGraphics

extension CGImage {
  /// Center crop to `targetSize`.
  func crop(toSize targetSize: CGSize) -> CGImage? {
    let x = floor(CGFloat(width) / 2 - targetSize.width / 2)
    let y = floor(CGFloat(height) / 2 - targetSize.height / 2)
    return cropping(to: CGRect(x: x, y: y, width: targetSize.width, height: targetSize.height))
  }
}
