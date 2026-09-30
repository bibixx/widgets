// Barcode library: zxing-cpp (SPM product `ZXingCpp`, v3.1.1).
// Chosen over ZXingObjC because it resolved and linked into both the app and the
// widget extension under Swift 6 on the first try, and writes every format we need
// (PDF417 included) straight to a 1-pixel-per-module CGImage.
// Nothing outside Shared/Barcode imports ZXingCpp, so it can be swapped here.
//
// Known wrapper quirks (v3.1.1, wrappers/ios/Sources/Wrapper/Writer/ZXIBarcodeWriter.mm):
// - `write` returns a +1 CGImage (straight from CGImageCreate), so `takeRetainedValue` is right.
// - It never releases the CGDataProvider/colour space it creates, so each encode leaks
//   width × height bytes. We only read the bits once and the NSCache below dedups repeats.
// - In DEBUG builds of the package it prints the matrix to stdout. Release builds don't.

import CoreGraphics
import Foundation
import ZXingCpp

enum BarcodeError: LocalizedError, Equatable {
  case invalid(String)
  case encodingFailed(String)

  var errorDescription: String? {
    switch self {
    case .invalid(let message): message
    case .encodingFailed(let message): "Can't encode this: \(message)"
    }
  }
}

enum BarcodeRenderer {
  /// Returns a 1-pixel-per-module image (no quiet zone baked in; views add padding).
  /// Linear codes are 1 px tall; PDF417 rows are 4 px tall (the format's module ratio).
  ///
  /// The image is 8-bit DeviceGray, black (0) on white (255), no alpha, top row first,
  /// `shouldInterpolate == false`. Draw it with nearest-neighbour scaling only.
  static func matrix(for text: String, symbology: Symbology) throws -> CGImage {
    let key = "\(symbology.rawValue)|\(text)" as NSString
    if let cached = cache.object(forKey: key) { return cached.image }

    let content = BarcodeValidation.normalized(text, for: symbology)
    guard !content.isEmpty else { throw BarcodeError.invalid("Enter card number") }

    let options = ZXIWriterOptions(format: symbology.zxingFormat, width: 0, height: 0, ecLevel: -1, margin: 0)
    let writer = ZXIBarcodeWriter(options: options)
    let raw: CGImage
    do {
      // The wrapper returns a +1 image straight from CGImageCreate.
      raw = try writer.write(content).takeRetainedValue()
    } catch {
      throw BarcodeError.encodingFailed(error.localizedDescription)
    }
    // Rebuild the image from the module bits so we control its exact pixel format
    // instead of handing the wrapper's unaligned, interpolating image to the views.
    guard let grid = ModuleGrid(raw), let image = grid.image() else {
      throw BarcodeError.encodingFailed("unexpected image from the barcode library")
    }
    cache.setObject(Box(image), forKey: key)
    return image
  }

  /// Pixel-exact upscale of a `matrix(for:symbology:)` image by replicating every module
  /// into a `moduleSize`² block, with a white quiet zone of `quietModules` on all sides.
  /// Linear (1-px-tall) codes are stretched to `linearHeight` pixels.
  ///
  /// Use this instead of `CGContext.draw` scaling when you need a bitmap (scan checks,
  /// tests): Core Graphics' scaled draw into an 8-bit gray bitmap context corrupts the
  /// rightmost ~3 source columns, which breaks every linear code.
  static func upscaled(_ matrix: CGImage, moduleSize: Int, linearHeight: Int? = nil, quietModules: Int = 10) -> CGImage? {
    guard moduleSize > 0, let grid = ModuleGrid(matrix) else { return nil }
    let scale = moduleSize
    let pad = quietModules * scale
    let codeHeight = grid.height == 1 ? (linearHeight ?? 60 * scale) : grid.height * scale
    let width = grid.width * scale + pad * 2
    let height = codeHeight + pad * 2
    let rowsPerModule = grid.height == 1 ? codeHeight : scale
    return makeGrayImage(width: width, height: height) { bytes, bytesPerRow in
      var line = [UInt8](repeating: 255, count: width)
      for my in 0..<grid.height {
        for mx in 0..<grid.width where grid.isDark(mx, my) {
          let start = pad + mx * scale
          for i in start..<(start + scale) { line[i] = 0 }
        }
        let firstRow = pad + my * rowsPerModule
        for y in firstRow..<(firstRow + rowsPerModule) {
          bytes.baseAddress!.advanced(by: y * bytesPerRow).update(from: line, count: width)
        }
        for i in 0..<width { line[i] = 255 }
      }
    }
  }

  private final class Box {
    let image: CGImage
    init(_ image: CGImage) { self.image = image }
  }

  // NSCache is thread-safe; the widget process gets its own instance.
  nonisolated(unsafe) private static let cache: NSCache<NSString, Box> = {
    let cache = NSCache<NSString, Box>()
    cache.countLimit = 64
    return cache
  }()
}

/// The dark/light modules of a barcode image, read straight from its pixel bytes.
private struct ModuleGrid {
  let width: Int
  let height: Int
  private let dark: [Bool]

  /// Accepts 8-bit single-channel images (the wrapper's and our own).
  init?(_ image: CGImage) {
    guard image.bitsPerComponent == 8, image.bitsPerPixel == 8,
          image.colorSpace?.model == .monochrome, image.decode == nil,
          let data = image.dataProvider?.data as Data? else { return nil }
    let width = image.width, height = image.height, bytesPerRow = image.bytesPerRow
    guard width > 0, height > 0, bytesPerRow >= width, data.count >= bytesPerRow * (height - 1) + width else { return nil }
    var dark = [Bool](repeating: false, count: width * height)
    data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
      for y in 0..<height {
        let row = y * bytesPerRow
        for x in 0..<width { dark[y * width + x] = buffer[row + x] < 128 }
      }
    }
    self.width = width
    self.height = height
    self.dark = dark
  }

  func isDark(_ x: Int, _ y: Int) -> Bool { dark[y * width + x] }

  func image() -> CGImage? {
    makeGrayImage(width: width, height: height) { bytes, bytesPerRow in
      for y in 0..<height {
        for x in 0..<width where isDark(x, y) { bytes[y * bytesPerRow + x] = 0 }
      }
    }
  }
}

/// Builds an 8-bit DeviceGray image (white background, 16-byte-aligned rows,
/// no interpolation). `draw` receives the zero-based pixel buffer and its bytesPerRow.
private func makeGrayImage(width: Int, height: Int, draw: (UnsafeMutableBufferPointer<UInt8>, Int) -> Void) -> CGImage? {
  let bytesPerRow = (width + 15) / 16 * 16
  var bytes = [UInt8](repeating: 255, count: bytesPerRow * height)
  bytes.withUnsafeMutableBufferPointer { draw($0, bytesPerRow) }
  guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
  return CGImage(
    width: width, height: height,
    bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: bytesPerRow,
    space: CGColorSpaceCreateDeviceGray(),
    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
    provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
  )
}

private extension Symbology {
  var zxingFormat: ZXIFormat {
    switch self {
    case .pdf417: .PDF_417
    case .qr: .QR_CODE
    case .aztec: .AZTEC
    case .dataMatrix: .DATA_MATRIX
    case .code128: .CODE_128
    case .code39: .CODE_39
    case .code93: .CODE_93
    case .ean13: .EAN_13
    case .ean8: .EAN_8
    case .upcA: .UPC_A
    case .upcE: .UPC_E
    case .itf: .ITF
    case .codabar: .CODABAR
    }
  }
}
