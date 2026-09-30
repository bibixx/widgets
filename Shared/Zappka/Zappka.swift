import Foundation

enum Zappka {
  static let symbology: Symbology = .pdf417
  static let host = "srln.pl"
  static let period: TimeInterval = 30

  /// The userId is interpolated as-is (not percent-encoded): that's the form the till accepts.
  static func payload(userId: String, code: String) -> String {
    "https://\(host)/view/dashboard?ploy=\(userId)&loyal=\(code)"
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
