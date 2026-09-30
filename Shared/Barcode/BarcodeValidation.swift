import Foundation

enum ValidationResult: Equatable, Sendable {
  case ok
  case warning(String)
  case error(String)

  var isError: Bool { if case .error = self { true } else { false } }

  var message: String? {
    switch self {
    case .ok: nil
    case .warning(let message), .error(let message): message
    }
  }
}

enum BarcodeValidation {
  static func validate(_ text: String, for symbology: Symbology) -> ValidationResult {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return .error("Enter card number") }

    switch symbology {
    case .ean13: return validateChecksummed(trimmed, lengths: (12, 13), name: "EAN-13")
    case .ean8: return validateChecksummed(trimmed, lengths: (7, 8), name: "EAN-8")
    case .upcA: return validateChecksummed(trimmed, lengths: (11, 12), name: "UPC-A")
    case .upcE: return validateUPCE(trimmed)
    case .itf:
      guard trimmed.allSatisfy(\.isASCIIDigit) else { return .error("ITF takes digits only") }
      guard trimmed.count.isMultiple(of: 2) else { return .error("ITF needs an even number of digits") }
      return .ok
    case .code39:
      let allowed = Set("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ -.$/+%")
      guard trimmed.uppercased().allSatisfy(allowed.contains) else {
        return .error("Code 39 allows A–Z, 0–9 and - . $ / + % space")
      }
      return trimmed == trimmed.uppercased() ? .ok : .warning("Lowercase letters will be uppercased")
    case .codabar:
      var body = Substring(trimmed.uppercased())
      let guards = Set("ABCD")
      if let first = body.first, guards.contains(first), let last = body.last, guards.contains(last), body.count >= 2 {
        body = body.dropFirst().dropLast()
      }
      let allowed = Set("0123456789-$:/.+")
      guard !body.isEmpty, body.allSatisfy(allowed.contains) else {
        return .error("Codabar allows 0–9 and - $ : / . + (optional A–D start/stop)")
      }
      return .ok
    case .code128, .code93:
      if !trimmed.allSatisfy(\.isASCII) {
        if symbology == .code93 { return .error("Code 93 takes ASCII characters only") }
        return .warning("Non-ASCII characters may not scan everywhere")
      }
      return encodable(trimmed, symbology)
    case .qr, .pdf417, .aztec, .dataMatrix:
      return encodable(trimmed, symbology)
    }
  }

  /// Applies the auto-fixes that `validate` reports as warnings.
  static func normalized(_ text: String, for symbology: Symbology) -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    switch symbology {
    case .ean13 where trimmed.count == 12,
         .ean8 where trimmed.count == 7,
         .upcA where trimmed.count == 11:
      guard let digit = checkDigit(trimmed) else { return trimmed }
      return trimmed + String(digit)
    case .upcE where trimmed.count == 7:
      guard let digit = upcECheckDigit(trimmed) else { return trimmed }
      return trimmed + String(digit)
    case .code39, .codabar:
      return trimmed.uppercased()
    default:
      return trimmed
    }
  }

  /// GS1 mod-10 check digit for EAN/UPC bodies (without the check digit).
  static func checkDigit(_ body: String) -> Int? {
    let digits = body.compactMap(\.wholeNumberValue)
    guard digits.count == body.count else { return nil }
    let sum = digits.reversed().enumerated().reduce(0) { acc, pair in
      acc + pair.element * (pair.offset.isMultiple(of: 2) ? 3 : 1)
    }
    return (10 - sum % 10) % 10
  }

  private static func validateChecksummed(_ text: String, lengths: (body: Int, full: Int), name: String) -> ValidationResult {
    guard text.allSatisfy(\.isASCIIDigit) else { return .error("\(name) takes digits only") }
    switch text.count {
    case lengths.body:
      guard let digit = checkDigit(text) else { return .error("\(name) takes digits only") }
      return .warning("Check digit added: \(digit)")
    case lengths.full:
      let body = String(text.dropLast())
      guard checkDigit(body) == text.last?.wholeNumberValue else { return .error("Check digit is wrong") }
      return .ok
    default:
      return .error("\(name) needs \(lengths.body) or \(lengths.full) digits")
    }
  }

  private static func validateUPCE(_ text: String) -> ValidationResult {
    guard text.allSatisfy(\.isASCIIDigit) else { return .error("UPC-E takes digits only") }
    guard text.first == "0" || text.first == "1" else { return .error("UPC-E must start with 0 or 1") }
    switch text.count {
    case 7:
      guard let digit = upcECheckDigit(text) else { return .error("UPC-E takes digits only") }
      return .warning("Check digit added: \(digit)")
    case 8:
      guard upcECheckDigit(String(text.dropLast())) == text.last?.wholeNumberValue else { return .error("Check digit is wrong") }
      return .ok
    default:
      return .error("UPC-E needs 7 or 8 digits")
    }
  }

  /// UPC-E's check digit is the UPC-A check digit of its expanded form.
  static func upcECheckDigit(_ body: String) -> Int? {
    upcEExpanded(body).flatMap(checkDigit)
  }

  /// The 11-digit UPC-A body (no check digit) a 7-digit UPC-E body expands to.
  static func upcEExpanded(_ body: String) -> String? {
    let d = body.compactMap(\.wholeNumberValue)
    guard d.count == 7, body.count == 7 else { return nil }
    let ns = d[0], x = Array(d[1...6])
    let expanded: [Int]
    switch x[5] {
    case 0, 1, 2: expanded = [ns, x[0], x[1], x[5], 0, 0, 0, 0, x[2], x[3], x[4]]
    case 3: expanded = [ns, x[0], x[1], x[2], 0, 0, 0, 0, 0, x[3], x[4]]
    case 4: expanded = [ns, x[0], x[1], x[2], x[3], 0, 0, 0, 0, 0, x[4]]
    default: expanded = [ns, x[0], x[1], x[2], x[3], x[4], 0, 0, 0, 0, x[5]]
    }
    return expanded.map(String.init).joined()
  }

  private static func encodable(_ text: String, _ symbology: Symbology) -> ValidationResult {
    do {
      _ = try BarcodeRenderer.matrix(for: text, symbology: symbology)
      return .ok
    } catch {
      return .error(error.localizedDescription)
    }
  }
}

private extension Character {
  var isASCIIDigit: Bool { isASCII && isNumber }
}
