import CoreGraphics
import CoreText
import Foundation
import UIKit

/// A barcode's modules as booleans (true = dark), read 1:1 from `BarcodeRenderer`'s image.
struct ModuleMatrix: Sendable {
  let width: Int
  let height: Int
  let bits: [Bool]

  subscript(x: Int, y: Int) -> Bool { bits[y * width + x] }

  init(image: CGImage) {
    let width = image.width, height = image.height
    self.width = width
    self.height = height
    var bytes = [UInt8](repeating: 255, count: width * height)
    bytes.withUnsafeMutableBytes { buffer in
      let context = CGContext(
        data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
        space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
      context?.interpolationQuality = .none
      // A 1:1 draw copies pixels exactly (no resampling).
      context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    bits = bytes.map { $0 < 128 }
  }

  /// Dark runs of a linear code as half-open module ranges.
  var bars: [Range<Int>] {
    var runs: [Range<Int>] = []
    var start: Int?
    for x in 0...width {
      let dark = x < width && self[x, 0]
      if dark, start == nil { start = x }
      if !dark, let s = start { runs.append(s..<x); start = nil }
    }
    return runs
  }
}

/// Renders a code to an exact device-pixel bitmap: black modules on white, module edges
/// snapped to whole pixels, no resampling anywhere. Linear codes get the caption notch:
/// a white box behind the caption that cuts the bars (as the old widgets renderer drew it).
enum CodeRaster {
  struct Notch: Hashable, Sendable {
    /// Horizontal extent in pixels, in the raster's coordinate space.
    var minX: Int
    var maxX: Int
    /// Height in pixels, measured up from the bottom.
    var height: Int
    /// Top-corner radius in pixels (`borderRadius: 4px 4px 0 0`).
    var topRadius: Int = 0
  }

  /// The human-readable number, drawn into the raster so it stays black on white in
  /// tinted/clear widget modes (text views get recoloured there; this image doesn't).
  struct Caption: Hashable, Sendable {
    var text: String
    var fontSize: CGFloat      // px
    var tracking: CGFloat      // px after every glyph (CSS letter-spacing)
    var baseline: CGFloat      // px above the bottom edge
    var centerX: CGFloat       // px
  }

  /// `padding` adds a white margin (in px) around the code (`paddingX` overrides it
  /// left and right): its own quiet zone for
  /// tinted/clear widgets, where the card's white body is removed.
  static func render(_ matrix: ModuleMatrix, symbology: Symbology, pixelWidth: Int, pixelHeight: Int, notch: Notch?, caption: Caption? = nil, padding: Int = 0, paddingX: Int? = nil) -> CGImage? {
    guard pixelWidth > 0, pixelHeight > 0, matrix.width > 0, matrix.height > 0 else { return nil }
    let padX = paddingX ?? padding
    let fullWidth = pixelWidth + 2 * padX, fullHeight = pixelHeight + 2 * padding
    var pixels = [UInt8](repeating: 255, count: fullWidth * fullHeight)
    let xEdges = edges(count: matrix.width, pixels: pixelWidth)

    // Coordinates below are in the code's own space; `padding` shifts them into the image.
    func fill(x0: Int, x1: Int, y0: Int, y1: Int, value: UInt8 = 0) {
      guard x1 > x0, y1 > y0 else { return }
      for y in max(0, y0)..<min(pixelHeight, y1) {
        let row = (y + padding) * fullWidth + padX
        for x in max(0, x0)..<min(pixelWidth, x1) { pixels[row + x] = value }
      }
    }

    if symbology.kind == .linear {
      for bar in matrix.bars {
        fill(x0: xEdges[bar.lowerBound], x1: xEdges[bar.upperBound], y0: 0, y1: pixelHeight)
      }
      if let notch {
        // White caption box with rounded top corners; bars show through the corner cut-outs.
        let top = pixelHeight - notch.height
        let r = min(notch.topRadius, notch.height, (notch.maxX - notch.minX) / 2)
        for y in top..<pixelHeight {
          var inset = 0
          if y - top < r {
            let dy = Double(r - (y - top)) - 0.5
            inset = Int((Double(r) - (Double(r * r) - dy * dy).squareRoot()).rounded())
          }
          fill(x0: notch.minX + inset, x1: notch.maxX - inset, y0: y, y1: y + 1, value: 255)
        }
      }
    } else {
      let yEdges = edges(count: matrix.height, pixels: pixelHeight)
      for y in 0..<matrix.height {
        var x = 0
        while x < matrix.width {
          guard matrix[x, y] else { x += 1; continue }
          var end = x
          while end < matrix.width, matrix[end, y] { end += 1 }
          fill(x0: xEdges[x], x1: xEdges[end], y0: yEdges[y], y1: yEdges[y + 1])
          x = end
        }
      }
    }

    if var caption {
      caption.centerX += CGFloat(padX)
      caption.baseline += CGFloat(padding)
      draw(caption, into: &pixels, width: fullWidth, height: fullHeight)
    }

    guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
    return CGImage(
      width: fullWidth, height: fullHeight, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: fullWidth,
      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
      provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
  }

  private static func draw(_ caption: Caption, into pixels: inout [UInt8], width: Int, height: Int) {
    let font = UIFont.monospacedSystemFont(ofSize: caption.fontSize, weight: .regular)
    let kern = caption.tracking
    let attributed = NSAttributedString(string: caption.text, attributes: [
      .font: font, .kern: kern, .foregroundColor: UIColor.black,
    ])
    let line = CTLineCreateWithAttributedString(attributed)
    // Kern also follows the last glyph; the old renderer centred it that way too (CSS
    // letter-spacing), so it stays in the width.
    let lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    pixels.withUnsafeMutableBytes { buffer in
      guard let context = CGContext(
        data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
        space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
      else { return }
      // Bottom-left origin: y is the baseline's height above the bottom edge.
      context.textPosition = CGPoint(x: caption.centerX - lineWidth / 2, y: caption.baseline)
      context.setShouldSmoothFonts(false)
      CTLineDraw(line, context)
    }
  }

  /// Pixel boundaries for `count` modules spread exactly across `pixels` (the code fills its
  /// box, as in the old renderer): each module is ⌊s⌋ or ⌈s⌉ pixels wide.
  static func edges(count: Int, pixels: Int) -> [Int] {
    (0...count).map { Int((Double($0) * Double(pixels) / Double(count)).rounded()) }
  }

  // MARK: Cache

  private final class Box { let image: CGImage; init(_ image: CGImage) { self.image = image } }
  nonisolated(unsafe) private static let cache: NSCache<NSString, Box> = {
    let cache = NSCache<NSString, Box>()
    cache.countLimit = 24
    return cache
  }()

  /// Encodes `text` and rasterises it, cached by everything that affects the pixels.
  static func image(for text: String, symbology: Symbology, pixelWidth: Int, pixelHeight: Int, notch: Notch?, caption: Caption? = nil, padding: Int = 0, paddingX: Int? = nil) throws -> CGImage {
    let key = "\(symbology.rawValue)|\(pixelWidth)x\(pixelHeight)+\(padding),\(paddingX ?? padding)|\(String(describing: notch))|\(String(describing: caption))|\(text)" as NSString
    if let hit = cache.object(forKey: key) { return hit.image }
    let matrix = ModuleMatrix(image: try BarcodeRenderer.matrix(for: text, symbology: symbology))
    guard let image = render(matrix, symbology: symbology, pixelWidth: pixelWidth, pixelHeight: pixelHeight, notch: notch, caption: caption, padding: padding, paddingX: paddingX) else {
      throw BarcodeError.encodingFailed("Nothing to draw")
    }
    cache.setObject(Box(image), forKey: key)
    return image
  }

  /// Module-matrix size, for layout (fitting 2D/stacked codes to their aspect ratio).
  static func matrixSize(for text: String, symbology: Symbology) throws -> CGSize {
    let image = try BarcodeRenderer.matrix(for: text, symbology: symbology)
    return CGSize(width: image.width, height: image.height)
  }
}
