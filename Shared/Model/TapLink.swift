import Foundation

/// Parses what the user typed as the widget's tap link. A bare domain (`zabka.pl`) gets
/// `https://`; anything with a scheme (`zappka://`, `mailto:`) is taken as is.
enum TapLink {
  enum Parsed: Equatable {
    case none
    case url(URL)
    case invalid
  }

  static func parse(_ text: String) -> Parsed {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return .none }
    // URL(string:) percent-encodes spaces instead of failing.
    guard !trimmed.contains(where: \.isWhitespace) else { return .invalid }
    // `zabka.pl:8080` parses with the scheme "zabka.pl"; real schemes have no dot.
    if let url = URL(string: trimmed), let scheme = url.scheme, !scheme.contains(".") {
      return .url(url)
    }
    if let url = URL(string: "https://\(trimmed)"), let host = url.host(), host.contains(".") {
      return .url(url)
    }
    return .invalid
  }
}
