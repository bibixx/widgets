import Foundation

/// What the code area of a card shows, resolved from a snapshot at a moment in time.
enum CardCode: Equatable {
  /// `text` is what gets encoded; `caption` is printed under linear codes.
  case code(text: String, caption: String?, isSample: Bool)
  case problem(symbol: String, message: String)

  static func resolve(_ card: CardSnapshot, at date: Date) -> CardCode {
    let symbology = card.symbology
    switch card.content {
    case .raw(let raw):
      if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        guard card.isPreview else { return .problem(symbol: "barcode", message: "Add the card number") }
        return code(symbology.placeholder, card, isSample: true)
      }
      let result = BarcodeValidation.validate(raw, for: symbology)
      if case .error(let message) = result { return .problem(symbol: "exclamationmark.triangle", message: message) }
      return code(BarcodeValidation.normalized(raw, for: symbology), card, isSample: false)

    case .zappka:
      guard let creds = card.zappkaCredentials else { return .problem(symbol: "key", message: "Add your Żappka secret") }
      guard !creds.userId.isEmpty else { return .problem(symbol: "person", message: "Add your Żappka User ID") }
      guard let payload = Zappka.payload(for: creds, at: date) else {
        return .problem(symbol: "key", message: "Add your Żappka secret")
      }
      return .code(text: payload, caption: nil, isSample: false)
    }
  }

  private static func code(_ text: String, _ card: CardSnapshot, isSample: Bool) -> CardCode {
    let caption = card.symbology.showsHumanReadableText && card.showsCaption ? text : nil
    return .code(text: text, caption: caption, isSample: isSample)
  }
}
