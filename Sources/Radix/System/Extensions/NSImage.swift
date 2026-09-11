import AppKit

enum NSImageExtensionError: Error {
  case unwrappingPNGRepresentationFailed
}

extension NSImage {
  var pngRepresentation: Data? {
    guard let tiff = tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
    return rep.representation(using: .png, properties: [:])
  }

  var jpgData: Data? {
    guard let tiff = tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
    return rep.representation(using: .jpeg, properties: [:])
  }

  /// Multi-representation TIFF container; the original build wrote this as
  /// the "heic" backup of a dynamic wallpaper.
  var heic: Data? {
    NSBitmapImageRep.representationOfImageReps(in: representations, using: .tiff, properties: [:])
  }

  func jpgWrite(to url: URL, options: Data.WritingOptions = .atomic) -> Bool {
    do {
      try jpgData?.write(to: url, options: options)
      return true
    } catch {
      NSLog("jpgWrite failed: \(error)")
      return false
    }
  }

  func heicWrite(to url: URL, options: Data.WritingOptions = .atomic) -> Bool {
    do {
      try heic?.write(to: url, options: options)
      return true
    } catch {
      NSLog("heicWrite failed: \(error)")
      return false
    }
  }

  func savePng(to url: URL) throws {
    guard let png = pngRepresentation else {
      throw NSImageExtensionError.unwrappingPNGRepresentationFailed
    }
    try png.write(to: url, options: .atomic)
  }

  var height: CGFloat { size.height }
  var width: CGFloat { size.width }

  func resize(withSize targetSize: NSSize) -> NSImage? {
    let frame = NSRect(origin: .zero, size: targetSize)
    guard let representation = bestRepresentation(for: frame, context: nil, hints: nil) else {
      return nil
    }
    return NSImage(size: targetSize, flipped: false) { _ in
      representation.draw(in: frame)
    }
  }

  /// Resize to fit within `targetSize`, keeping the aspect ratio.
  func resizeMaintainingAspectRatio(withSize targetSize: NSSize) -> NSImage? {
    let scaleFactor = min(targetSize.width / width, targetSize.height / height)
    let newSize = NSSize(width: floor(width * scaleFactor), height: floor(height * scaleFactor))
    return resize(withSize: newSize)
  }
}
