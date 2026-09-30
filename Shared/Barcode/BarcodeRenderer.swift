// Barcode library: zxing-cpp (SPM product `ZXingCpp`, v3.1.1).
// Chosen over ZXingObjC because it resolved and linked into both the app and the
// widget extension under Swift 6 on the first try, and writes every format we need
// (PDF417 included) straight to a 1-pixel-per-module CGImage.
// Nothing outside Shared/Barcode imports ZXingCpp, so it can be swapped here.

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
  static func matrix(for text: String, symbology: Symbology) throws -> CGImage {
    let key = "\(symbology.rawValue)|\(text)" as NSString
    if let cached = cache.object(forKey: key) { return cached.image }

    let content = BarcodeValidation.normalized(text, for: symbology)
    guard !content.isEmpty else { throw BarcodeError.invalid("Enter card number") }

    let options = ZXIWriterOptions(format: symbology.zxingFormat, width: 0, height: 0, ecLevel: -1, margin: 0)
    let writer = ZXIBarcodeWriter(options: options)
    let image: CGImage
    do {
      // The wrapper returns a +1 image straight from CGImageCreate.
      image = try writer.write(content).takeRetainedValue()
    } catch {
      throw BarcodeError.encodingFailed(error.localizedDescription)
    }
    cache.setObject(Box(image), forKey: key)
    return image
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
