import CoreGraphics
import ZXingCpp

/// Reads barcodes back from a rendered image. Used by the editor's "Scan check"
/// and by tests. zxing's reader rather than Vision, because Vision's barcode
/// detector returns nothing in the iOS simulator.
enum BarcodeDecoder {
  static func decode(_ image: CGImage) -> [String] {
    let options = ZXIReaderOptions()
    options.tryHarder = true
    options.tryRotate = false
    options.maxNumberOfSymbols = 4
    let reader = ZXIBarcodeReader(options: options)
    guard let results = try? reader.read(image) else { return [] }
    return results.map(\.text)
  }

  /// Whether a decoded payload is what `text` encodes as `symbology`, allowing for the
  /// ways readers report the same symbol differently:
  /// - UPC-A and UPC-E come back as 13-digit EAN-13 (zxing always; Vision for UPC-A),
  ///   UPC-E possibly expanded to its UPC-A form;
  /// - Codabar may come back with or without its A–D start/stop characters.
  static func matches(_ decoded: String, text: String, symbology: Symbology) -> Bool {
    let expected = BarcodeValidation.normalized(text, for: symbology)
    if decoded == expected { return true }
    switch symbology {
    case .upcA:
      return decoded == "0" + expected
    case .upcE:
      guard expected.count == 8, let upcA = BarcodeValidation.upcEExpanded(String(expected.prefix(7))) else { return false }
      let full = upcA + String(expected.suffix(1))
      return decoded == full || decoded == "0" + full
    case .codabar:
      let guards = Set("ABCD")
      func strip(_ s: String) -> Substring {
        guard s.count >= 2, let f = s.first, let l = s.last, guards.contains(f), guards.contains(l) else { return Substring(s) }
        return s.dropFirst().dropLast()
      }
      return strip(decoded.uppercased()) == strip(expected)
    default:
      return false
    }
  }
}
