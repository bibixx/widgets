import Foundation

/// Every code type a card can use. Raw values are persisted: never rename them.
enum Symbology: String, Codable, CaseIterable, Identifiable, Sendable {
  case pdf417
  case qr, aztec, dataMatrix
  case code128, code39, code93
  case ean13, ean8, upcA, upcE
  case itf, codabar

  enum Kind: Sendable { case twoD, stacked, linear }
  enum Keyboard: Sendable { case numberPad, asciiCapable }

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .pdf417: "PDF417"
    case .qr: "QR Code"
    case .aztec: "Aztec"
    case .dataMatrix: "Data Matrix"
    case .code128: "Code 128"
    case .code39: "Code 39"
    case .code93: "Code 93"
    case .ean13: "EAN-13"
    case .ean8: "EAN-8"
    case .upcA: "UPC-A"
    case .upcE: "UPC-E"
    case .itf: "ITF"
    case .codabar: "Codabar"
    }
  }

  var kind: Kind {
    switch self {
    case .pdf417: .stacked
    case .qr, .aztec, .dataMatrix: .twoD
    default: .linear
    }
  }

  var isSquare: Bool { kind == .twoD }
  /// Linear codes print their digits so a cashier can type them in.
  var showsHumanReadableText: Bool { kind == .linear }

  var keyboard: Keyboard {
    switch self {
    case .ean13, .ean8, .upcA, .upcE, .itf: .numberPad
    default: .asciiCapable
    }
  }

  /// Sample content drawn (faded) while the card number is still empty.
  var placeholder: String {
    switch self {
    case .pdf417, .qr, .aztec, .dataMatrix: "https://example.com/card/0123456789"
    case .code128: "0123456789012"
    case .code39: "CARD-12345"
    case .code93: "CARD12345"
    case .ean13: "5901234123457"
    case .ean8: "96385074"
    case .upcA: "036000291452"
    case .upcE: "01234565"
    case .itf: "12345678901231"
    case .codabar: "A123456B"
    }
  }
}
