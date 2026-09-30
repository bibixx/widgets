import Foundation

enum Zappka {
  /// Fixed code types: the tills read both. The Żappka app itself shows a QR code.
  static let symbology: Symbology = .pdf417
  static let squareSymbology: Symbology = .qr
  static let host = "srln.pl"
  static let period: TimeInterval = 30

  /// The userId is interpolated as-is (not percent-encoded): that's the form the till accepts.
  static func payload(userId: String, code: String) -> String {
    "https://\(host)/view/dashboard?ploy=\(userId)&loyal=\(code)"
  }

  /// The User ID from a Żappka code's payload (`…/dashboard?ploy=<userId>&loyal=…`),
  /// e.g. read from a screenshot. Also accepts the old `zlgn.pl` host.
  static func userId(fromPayload payload: String) -> String? {
    guard let components = URLComponents(string: payload),
          let host = components.host, [Zappka.host, "zlgn.pl"].contains(host),
          let userId = components.queryItems?.first(where: { $0.name == "ploy" })?.value,
          !userId.isEmpty
    else { return nil }
    return userId
  }

  static func payload(for creds: ZappkaCredentials, at date: Date) -> String? {
    guard creds.isValid, let secret = creds.secretData else { return nil }
    return payload(userId: creds.userId, code: TOTP(secret: secret, period: period).code(at: date))
  }

  static func code(for creds: ZappkaCredentials, at date: Date) -> String? {
    guard creds.isValid, let secret = creds.secretData else { return nil }
    return TOTP(secret: secret, period: period).code(at: date)
  }

  static func window(containing date: Date) -> DateInterval {
    TOTP(secret: Data(), period: period).window(containing: date)
  }
}
