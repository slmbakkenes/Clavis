// Modified class taken from https://github.com/jacklandrin/OnlySwitch/blob/main/OnlySwitch/EverySwitch/TopNotchSwitch.swift
// All rights to the author.
//
// Hides the notch by re-rendering the wallpaper with a black bar across the
// menu bar area. Originals and processed copies live under
// ~/Library/Application Support/<CFBundleName>/{original,processed}.

import AVFoundation
import AppKit
import UniformTypeIdentifiers

struct HeicMetaDataTag {
  let type: String  // solar, h24, apr
  let plist: String  // base64 property list
}

@MainActor
final class NotchHelper {
  static let shared = NotchHelper()

  private var currentImageName = ""

  private init() {}

  private var appName: String {
    Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Clavis"
  }

  private var myAppPath: URL? {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
      .appendingPathComponent(appName)
  }

  private func recoverNotch(screen: NSScreen) {
    guard
      let originalPath = myAppPath?.appendingPathComponent("original").appendingPathComponent(
        currentImageName)
    else { return }
    setDesktopImageURL(url: originalPath, screen: screen)
  }

  /// Toggles: a processed wallpaper is restored to the original, an original
  /// is swapped for its processed copy, anything else gets processed.
  func hideNotch() {
    let workspace = NSWorkspace.shared
    for screen in NSScreen.screens {
      guard let path = workspace.desktopImageURL(for: screen) else { return }

      if path.path.contains("/\(appName)/processed/") {
        currentImageName = path.lastPathComponent
        recoverNotch(screen: screen)
        continue
      }

      if let myAppPath, path.path.contains("/\(appName)/original/") {
        currentImageName = path.lastPathComponent
        let processedURL = myAppPath.appendingPathComponent("processed").appendingPathComponent(
          currentImageName)
        if FileManager.default.fileExists(atPath: processedURL.path) {
          setDesktopImageURL(url: processedURL, screen: screen)
          continue
        }
      }

      guard let currentWallpaperImage = NSImage(contentsOf: path) else { return }

      if path.pathExtension == "heic" {
        let metaDataTag: HeicMetaDataTag
        do {
          let imageData = try Data(contentsOf: path)
          metaDataTag = try extractMetaData(imageData: imageData)
        } catch {
          NSLog("Could not read wallpaper metadata: \(error)")
          return
        }
        hideHeicDesktopNotch(image: currentWallpaperImage, metaDataTag: metaDataTag, screen: screen)
      } else {
        hideSingleDesktopNotch(image: currentWallpaperImage, screen: screen)
      }
    }
  }

  private func extractMetaData(imageData: Data) throws -> HeicMetaDataTag {
    guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil) else {
      throw MetadataExtractorError.imageSourceNotCreated
    }
    guard let imageMetadata = CGImageSourceCopyMetadataAtIndex(imageSource, 0, nil) else {
      throw MetadataExtractorError.imageMetadataNotCreated
    }

    final class Found {
      var type = ""
      var plist = ""
    }
    let found = Found()

    CGImageMetadataEnumerateTagsUsingBlock(imageMetadata, nil, nil) { value, metadataTag -> Bool in
      let valueString = value as String
      guard let valueTag = CGImageMetadataTagCopyValue(metadataTag) as? String else { return true }
      if valueString.starts(with: "apple_desktop:solar") {
        found.type = "solar"
        found.plist = valueTag
      } else if valueString.starts(with: "apple_desktop:h24") {
        found.type = "h24"
        found.plist = valueTag
      } else if valueString.starts(with: "apple_desktop:apr") {
        found.type = "apr"
        found.plist = valueTag
      }
      return true
    }
    return HeicMetaDataTag(type: found.type, plist: found.plist)
  }

  private func hideHeicDesktopNotch(image: NSImage, metaDataTag: HeicMetaDataTag, screen: NSScreen) {
    let imageReps = image.representations
    if imageReps.count == 1 && metaDataTag.type.isEmpty {
      hideSingleDesktopNotch(image: image, screen: screen)
      return
    }

    let destinationData = NSMutableData()
    let options = [kCGImageDestinationLossyCompressionQuality: 1.0]

    guard
      let imageDestination = CGImageDestinationCreateWithData(
        destinationData, AVFileType.heic as CFString, imageReps.count, nil)
    else { return }

    for (index, rep) in imageReps.enumerated() {
      guard let bitmapRep = rep as? NSBitmapImageRep else { continue }
      let nsImage = NSImage()
      nsImage.addRepresentation(bitmapRep)
      guard let processedImage = addBlackRect(on: nsImage, screen: screen) else { continue }

      if index == 0 {
        let imageMetaData = CGImageMetadataCreateMutable()
        guard
          let imageMetaDataTag = CGImageMetadataTagCreate(
            "http://ns.apple.com/namespace/1.0/" as CFString,
            "apple_desktop" as CFString,
            metaDataTag.type as CFString,
            CGImageMetadataType.string,
            metaDataTag.plist as CFTypeRef)
        else { return }
        let success = CGImageMetadataSetTagWithPath(
          imageMetaData, nil, "xmp:\(metaDataTag.type)" as CFString, imageMetaDataTag)
        if !success { return }
        CGImageDestinationAddImageAndMetadata(
          imageDestination, processedImage, imageMetaData, options as CFDictionary)
      } else {
        CGImageDestinationAddImage(imageDestination, processedImage, options as CFDictionary)
      }
    }

    CGImageDestinationFinalize(imageDestination)
    let imageName = UUID().uuidString
    guard
      let url = saveHeicData(data: destinationData as Data, isProcessed: true, imageName: imageName)
    else { return }
    _ = saveHeicData(image: image, isProcessed: false, imageName: imageName)
    setDesktopImageURL(url: url, screen: screen)
  }

  private func hideSingleDesktopNotch(image: NSImage, screen: NSScreen) {
    guard let finalCGImage = addBlackRect(on: image, screen: screen) else { return }

    let imageName = UUID().uuidString
    guard let imageURL = saveCGImage(finalCGImage, isProcessed: true, imageName: imageName) else {
      return
    }
    _ = saveImage(image, isProcessed: false, imageName: imageName)
    setDesktopImageURL(url: imageURL, screen: screen)
  }

  private func addBlackRect(on image: NSImage, screen: NSScreen) -> CGImage? {
    let scale = screen.backingScaleFactor
    let visibleScreenSizePixels = NSSize(
      width: screen.visibleFrame.size.width * scale,
      height: screen.visibleFrame.size.height * scale)
    let fullScreenSizePixels = NSSize(
      width: screen.frame.size.width * scale,
      height: screen.frame.size.height * scale)
    let barHeight = fullScreenSizePixels.height - visibleScreenSizePixels.height

    var imageRect = CGRect(origin: .zero, size: visibleScreenSizePixels)
    guard
      let wallpaper = image.cgImage(forProposedRect: &imageRect, context: nil, hints: nil)?
        .crop(toSize: visibleScreenSizePixels),
      let context = createContext(size: fullScreenSizePixels)
    else { return nil }

    context.draw(wallpaper, in: CGRect(origin: .zero, size: visibleScreenSizePixels))
    context.setFillColor(.black)
    context.fill(
      CGRect(
        origin: CGPoint(x: 0, y: fullScreenSizePixels.height - barHeight),
        size: CGSize(width: fullScreenSizePixels.width, height: barHeight)))
    return context.makeImage()
  }

  private func setDesktopImageURL(url: URL, screen: NSScreen) {
    do {
      try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
    } catch {
      NSLog("Could not set desktop image URL: \(error)")
    }
  }

  private func saveImage(_ image: NSImage, isProcessed: Bool, imageName: String) -> URL? {
    guard let destinationURL = saveDestination(isProcessed: isProcessed, imageName: imageName, type: "jpg")
    else { return nil }
    return image.jpgWrite(to: destinationURL, options: .withoutOverwriting) ? destinationURL : nil
  }

  private func saveCGImage(_ image: CGImage, isProcessed: Bool, imageName: String) -> URL? {
    guard
      let destinationURL = saveDestination(isProcessed: isProcessed, imageName: imageName, type: "jpg"),
      let destination = CGImageDestinationCreateWithURL(
        destinationURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
    else { return nil }
    CGImageDestinationAddImage(destination, image, nil)
    return CGImageDestinationFinalize(destination) ? destinationURL : nil
  }

  private func saveHeicData(image: NSImage, isProcessed: Bool, imageName: String) -> URL? {
    guard let destinationURL = saveDestination(isProcessed: isProcessed, imageName: imageName, type: "heic")
    else { return nil }
    return image.heicWrite(to: destinationURL, options: .withoutOverwriting) ? destinationURL : nil
  }

  private func saveHeicData(data: Data, isProcessed: Bool, imageName: String) -> URL? {
    guard let destinationURL = saveDestination(isProcessed: isProcessed, imageName: imageName, type: "heic")
    else { return nil }
    do {
      try data.write(to: destinationURL, options: .withoutOverwriting)
      return destinationURL
    } catch {
      NSLog("Could not write wallpaper: \(error)")
      return nil
    }
  }

  private func saveDestination(isProcessed: Bool, imageName: String, type: String) -> URL? {
    guard let imagePath = myAppPath?.appendingPathComponent(isProcessed ? "processed" : "original")
    else { return nil }
    if !FileManager.default.fileExists(atPath: imagePath.path) {
      do {
        try FileManager.default.createDirectory(at: imagePath, withIntermediateDirectories: true)
      } catch {
        NSLog("Could not create wallpaper directory: \(error)")
        return nil
      }
    }
    return imagePath.appendingPathComponent("\(imageName).\(type)")
  }

  private func createContext(size: CGSize) -> CGContext? {
    CGContext(
      data: nil,
      width: Int(size.width),
      height: Int(size.height),
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
  }
}
