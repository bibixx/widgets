import Foundation

enum Zappka {
  /// Fixed code types: the tills read both. The Żappka app itself shows a QR code.
  static let symbology: Symbology = .pdf417
  static let squareSymbology: Symbology = .qr
  static let host = "srln.pl"
  static let period: TimeInterval = 30
  /// Codes are shown this many seconds before their TOTP window starts, to make up for the till
  /// handing the scan to Żabka's server a moment later (and WidgetKit showing an entry late).
  /// 0 switches exactly on :00/:30; raise it from the editor's hidden debug panel.
  static let defaultLeadTime: TimeInterval = 0
  static let leadTimeKey = "zappkaLeadTime"
  /// Shared App Group defaults, so the app and the widget agree. Tweaked from the editor's
  /// hidden debug panel.
  static var leadTime: TimeInterval {
    UserDefaults(suiteName: SharedStore.appGroup)?.object(forKey: leadTimeKey) as? Double ?? defaultLeadTime
  }
  /// Drawn faded in the editor preview until the card is signed in.
  static let samplePayload = payload(userId: "000000000", code: "000000")

  /// "505968488" → "505 968 488".
  static func formatPhone(_ digits: String) -> String {
    stride(from: 0, to: digits.count, by: 3)
      .map { String(digits.dropFirst($0).prefix(3)) }
      .joined(separator: " ")
  }

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

  static func payload(for creds: ZappkaCredentials, at date: Date, lead: TimeInterval = leadTime) -> String? {
    guard let code = code(for: creds, at: date, lead: lead) else { return nil }
    return payload(userId: creds.userId, code: code)
  }

  /// The code shown at `date`: the TOTP code for `date + lead`.
  static func code(for creds: ZappkaCredentials, at date: Date, lead: TimeInterval = leadTime) -> String? {
    guard creds.isValid, let secret = creds.secretData else { return nil }
    return TOTP(secret: secret, period: period).code(at: date.addingTimeInterval(lead))
  }

  /// The window during which one code is shown: a TOTP window moved `lead` seconds earlier.
  static func window(containing date: Date, lead: TimeInterval = leadTime) -> DateInterval {
    let totp = TOTP(secret: Data(), period: period).window(containing: date.addingTimeInterval(lead))
    return DateInterval(start: totp.start.addingTimeInterval(-lead), duration: totp.duration)
  }
}
