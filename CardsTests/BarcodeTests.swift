import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import Cards

struct BarcodeValidationTests {
  @Test func emptyIsError() {
    #expect(BarcodeValidation.validate("  ", for: .code128) == .error("Enter card number"))
  }

  @Test func ean13CheckDigit() {
    #expect(BarcodeValidation.validate("590123412345", for: .ean13) == .warning("Check digit added: 7"))
    #expect(BarcodeValidation.normalized("590123412345", for: .ean13) == "5901234123457")
    #expect(BarcodeValidation.validate("5901234123457", for: .ean13) == .ok)
    #expect(BarcodeValidation.validate("5901234123458", for: .ean13).isError)
    #expect(BarcodeValidation.validate("59012341234", for: .ean13).isError)
    #expect(BarcodeValidation.validate("59012341234a", for: .ean13).isError)
  }

  @Test func ean8AndUPC() {
    #expect(BarcodeValidation.validate("9638507", for: .ean8) == .warning("Check digit added: 4"))
    #expect(BarcodeValidation.validate("96385074", for: .ean8) == .ok)
    #expect(BarcodeValidation.validate("03600029145", for: .upcA) == .warning("Check digit added: 2"))
    #expect(BarcodeValidation.validate("036000291452", for: .upcA) == .ok)
    #expect(BarcodeValidation.validate("0123456", for: .upcE) == .warning("Check digit added: 5"))
    #expect(BarcodeValidation.validate("01234565", for: .upcE) == .ok)
    #expect(BarcodeValidation.validate("91234565", for: .upcE).isError)
  }

  @Test func itf() {
    #expect(BarcodeValidation.validate("1234", for: .itf) == .ok)
    #expect(BarcodeValidation.validate("123", for: .itf).isError)
  }

  @Test func code39() {
    #expect(BarcodeValidation.validate("CARD-1", for: .code39) == .ok)
    #expect(BarcodeValidation.validate("card-1", for: .code39) == .warning("Lowercase letters will be uppercased"))
    #expect(BarcodeValidation.normalized("card-1", for: .code39) == "CARD-1")
    #expect(BarcodeValidation.validate("CARD#1", for: .code39).isError)
  }

  @Test func codabar() {
    #expect(BarcodeValidation.validate("A123456B", for: .codabar) == .ok)
    #expect(BarcodeValidation.validate("123-456", for: .codabar) == .ok)
    #expect(BarcodeValidation.validate("12X", for: .codabar).isError)
  }

  @Test func freeText() {
    #expect(BarcodeValidation.validate("anything goes", for: .qr) == .ok)
    #expect(BarcodeValidation.validate("zażółć", for: .code128) == .warning("Non-ASCII characters may not scan everywhere"))
    #expect(BarcodeValidation.validate("zażółć", for: .code93).isError)
  }

  @Test func tooLongIsErrorNotCrash() {
    let huge = String(repeating: "x", count: 5000)
    #expect(BarcodeValidation.validate(huge, for: .qr).isError)
  }
}

struct BarcodeRendererTests {
  // Every symbology Vision reads.
  static let roundTrips: [(Symbology, String)] = [
    (.pdf417, "12345678"),
    (.qr, "12345678"),
    (.aztec, "12345678"),
    (.dataMatrix, "12345678"),
    (.code128, "12345678"),
    (.code39, "CARD-1234"),
    (.code93, "CARD1234"),
    (.ean13, "590123412345"),
    (.ean8, "96385074"),
    (.upcA, "036000291452"),
    (.upcE, "01234565"),
    (.itf, "12345678901231"),
    (.codabar, "A123456B"),
  ]

  @Test(arguments: roundTrips.indices)
  func roundTrip(_ index: Int) throws {
    let (symbology, input) = Self.roundTrips[index]
    let payloads = try TestDecoder.decodeMatrix(input, symbology)
    // Readers report UPC-A/E as EAN-13 and may drop Codabar start/stop; `matches` allows for that.
    let matched = !payloads.isEmpty && payloads.allSatisfy { BarcodeDecoder.matches($0, text: input, symbology: symbology) }
    #expect(matched, "\(symbology.displayName): decoded \(payloads)")
  }

  @Test func decodedPayloadMatching() {
    #expect(BarcodeDecoder.matches("0036000291452", text: "03600029145", symbology: .upcA))
    #expect(BarcodeDecoder.matches("0012345000065", text: "01234565", symbology: .upcE))
    #expect(BarcodeDecoder.matches("012345000065", text: "0123456", symbology: .upcE))
    #expect(BarcodeDecoder.matches("123456", text: "a123456b", symbology: .codabar))
    #expect(!BarcodeDecoder.matches("0012345000066", text: "01234565", symbology: .upcE))
    #expect(!BarcodeDecoder.matches("1234567", text: "12345678", symbology: .code128))
  }

  @Test func zappkaShapedPayloadRoundTrips() throws {
    let payload = "https://srln.pl/view/dashboard?ploy=123456&loyal=000000"
    let payloads = try TestDecoder.decodeMatrix(payload, .pdf417)
    #expect(!payloads.isEmpty && payloads.allSatisfy { $0 == payload })
  }

  @Test func pdf417IsWideAndShort() throws {
    let payload = "https://srln.pl/view/dashboard?ploy=123456&loyal=000000"
    let image = try BarcodeRenderer.matrix(for: payload, symbology: .pdf417)
    let ratio = Double(image.width) / Double(image.height)
    #expect(ratio > 1.5, "PDF417 \(image.width)×\(image.height)")
  }

  @Test func linearIsOnePixelTall() throws {
    let image = try BarcodeRenderer.matrix(for: "12345678", symbology: .code128)
    #expect(image.height == 1)
  }

  @Test func matrixIsCleanOnePixelPerModuleImage() throws {
    let image = try BarcodeRenderer.matrix(for: "12345678", symbology: .code128)
    #expect(image.bitsPerPixel == 8 && image.bitsPerComponent == 8)
    #expect(image.bytesPerRow % 16 == 0)
    #expect(!image.shouldInterpolate)
    #expect(image.colorSpace?.model == .monochrome)
    let bytes = Array(image.dataProvider!.data! as Data)
    let modules = String(bytes.prefix(image.width).map { $0 < 128 ? "X" : "." })
    // Start C, 12 34 56 78, check, stop (ends with the 2331112 stop pattern).
    #expect(modules == "XX.X..XXX..X.XX..XXX..X...X.XX...XXX...X.XX.XX....X.X..X...XXX.XX.XX...XXX.X.XX")
  }

  @Test func upscaleIsPixelExact() throws {
    let matrix = try BarcodeRenderer.matrix(for: "12345678", symbology: .code128)
    let big = try #require(BarcodeRenderer.upscaled(matrix, moduleSize: 3, linearHeight: 10, quietModules: 2))
    #expect(big.width == (matrix.width + 4) * 3 && big.height == 10 + 12)
    let src = Array(matrix.dataProvider!.data! as Data)
    let dst = Array(big.dataProvider!.data! as Data)
    for y in 0..<big.height {
      for x in 0..<big.width {
        let mx = x / 3 - 2
        let inCode = (6..<16).contains(y) && (0..<matrix.width).contains(mx)
        let expected: UInt8 = inCode ? src[mx] : 255
        #expect(dst[y * big.bytesPerRow + x] == expected, "pixel \(x),\(y)")
      }
    }
  }

  /// The view layer shows the raw matrix via `Image(decorative:scale:).resizable().interpolation(.none)`
  /// stretched to arbitrary (non-integer) sizes. Check that path still produces a readable code.
  @MainActor
  @Test(arguments: Symbology.allCases)
  func swiftUIDisplayPathDecodes(_ symbology: Symbology) throws {
    let text = symbology.kind != .linear ? "https://srln.pl/view/dashboard?ploy=123456&loyal=000000" : symbology.placeholder
    let matrix = try BarcodeRenderer.matrix(for: text, symbology: symbology)
    // Points per module: deliberately non-integer, rendered at a device-like 3× scale
    // (≈ 7.1 px per module, so modules alternate between 7 and 8 px).
    let moduleWidth = 2.37
    let width = Double(matrix.width) * moduleWidth
    let height = symbology.kind == .linear ? 90 : Double(matrix.height) * moduleWidth
    let view = Image(decorative: matrix, scale: 1)
      .resizable()
      .interpolation(.none)
      .frame(width: width, height: height)
      .padding(40)
      .background(Color.white)
      .environment(\.colorScheme, .light)
    let renderer = ImageRenderer(content: view)
    renderer.scale = 3
    let rendered = try #require(renderer.cgImage)
    let payloads = BarcodeDecoder.decode(rendered)
    let matched = !payloads.isEmpty && payloads.allSatisfy { BarcodeDecoder.matches($0, text: text, symbology: symbology) }
    #expect(matched, "\(symbology.displayName): decoded \(payloads)")
  }

  @Test func performance() throws {
    let start = Date()
    for i in 0..<100 {
      _ = try BarcodeRenderer.matrix(for: "https://srln.pl/view/dashboard?ploy=123456&loyal=\(String(format: "%06d", i))", symbology: .pdf417)
    }
    #expect(Date().timeIntervalSince(start) < 1)
  }
}
