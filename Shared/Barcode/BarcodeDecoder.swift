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
}
