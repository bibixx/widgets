import CoreGraphics
import Foundation
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
  // Every symbology Vision reads. UPC-A is read by Vision as EAN-13 with a leading 0.
  static let roundTrips: [(Symbology, String, String)] = [
    (.pdf417, "12345678", "12345678"),
    (.qr, "12345678", "12345678"),
    (.aztec, "12345678", "12345678"),
    (.dataMatrix, "12345678", "12345678"),
    (.code128, "12345678", "12345678"),
    (.code39, "CARD-1234", "CARD-1234"),
    (.code93, "CARD1234", "CARD1234"),
    (.ean13, "590123412345", "5901234123457"),
    (.ean8, "96385074", "96385074"),
    (.upcA, "036000291452", "0036000291452"),
    (.upcE, "01234565", "01234565"),
    (.itf, "12345678901231", "12345678901231"),
    (.codabar, "A123456B", "A123456B"),
  ]

  @Test(arguments: roundTrips.indices)
  func roundTrip(_ index: Int) throws {
    let (symbology, input, expected) = Self.roundTrips[index]
    let payloads = try TestDecoder.decodeMatrix(input, symbology)
    // Vision may or may not include Codabar start/stop characters.
    let matched = !payloads.isEmpty && payloads.allSatisfy { $0 == expected || (symbology == .codabar && $0 == "123456") }
    #expect(matched, "\(symbology.displayName): decoded \(payloads)")
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

  @Test func performance() throws {
    let start = Date()
    for i in 0..<100 {
      _ = try BarcodeRenderer.matrix(for: "https://srln.pl/view/dashboard?ploy=123456&loyal=\(String(format: "%06d", i))", symbology: .pdf417)
    }
    #expect(Date().timeIntervalSince(start) < 1)
  }
}
