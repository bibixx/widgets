import CoreGraphics
import Vision
@testable import Cards

/// Test helper: upscales a 1-px-per-module matrix with a white quiet zone and reads it back.
enum TestDecoder {
  /// Pixel-exact (module replication), not CGContext scaling: CG's scaled draw into an
  /// 8-bit gray context corrupts the rightmost source columns and broke every linear code.
  static func upscaled(_ matrix: CGImage, scale: Int = 8, linearHeight: Int = 120, quietModules: Int = 10) -> CGImage {
    BarcodeRenderer.upscaled(matrix, moduleSize: scale, linearHeight: linearHeight, quietModules: quietModules)!
  }

  static func decode(_ image: CGImage) throws -> [(payload: String, symbology: VNBarcodeSymbology)] {
    let request = VNDetectBarcodesRequest()
    try VNImageRequestHandler(cgImage: image).perform([request])
    return (request.results ?? []).compactMap { obs in
      obs.payloadStringValue.map { ($0, obs.symbology) }
    }
  }

  /// Decodes with zxing everywhere, plus Vision on a real device (Vision's detector
  /// finds nothing in the simulator).
  static func decodeAll(_ image: CGImage) throws -> [String] {
    var payloads = BarcodeDecoder.decode(image)
    #if !targetEnvironment(simulator)
    payloads += try decode(image).map(\.payload)
    #endif
    return payloads
  }

  static func decodeMatrix(_ text: String, _ symbology: Symbology) throws -> [String] {
    let matrix = try BarcodeRenderer.matrix(for: text, symbology: symbology)
    return try decodeAll(upscaled(matrix))
  }
}
