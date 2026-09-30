import CoreGraphics
import Vision
@testable import Cards

/// Test helper: scales a 1-px-per-module matrix up with a white quiet zone and reads it back with Vision.
enum TestDecoder {
  static func upscaled(_ matrix: CGImage, scale: Int = 8, linearHeight: Int = 120, quietModules: Int = 10) -> CGImage {
    let isLinear = matrix.height == 1
    let codeW = matrix.width * scale
    let codeH = isLinear ? linearHeight : matrix.height * scale
    let pad = quietModules * scale
    let width = codeW + pad * 2, height = codeH + pad * 2
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    ctx.setFillColor(gray: 1, alpha: 1)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    ctx.interpolationQuality = .none
    ctx.draw(matrix, in: CGRect(x: pad, y: pad, width: codeW, height: codeH))
    return ctx.makeImage()!
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
