import AppKit
import ImageIO

/// Keeps decoded, shelf-sized covers in memory so hovering and scrolling never read the disk.
enum CoverCache {
  /// Sharp at 2x on the shelf and in the details editor.
  nonisolated static let maxPixelSize = 480

  private static let images: NSCache<NSString, NSImage> = {
    let cache = NSCache<NSString, NSImage>()
    cache.countLimit = 400
    return cache
  }()

  static func cached(_ path: String) -> NSImage? {
    images.object(forKey: path as NSString)
  }

  static func image(for path: String) async -> NSImage? {
    if let cached = cached(path) { return cached }
    guard let decoded = await decode(path) else { return nil }
    let image = NSImage(cgImage: decoded, size: .zero)
    images.setObject(image, forKey: path as NSString)
    return image
  }

  static func invalidate(_ path: String?) {
    guard let path else { return }
    images.removeObject(forKey: path as NSString)
  }

  @concurrent private nonisolated static func decode(_ path: String) async -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)
    else { return nil }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
    ]
    return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
  }
}
