import CryptoKit
import Foundation

/// RFC 6238 time-based one-time password, HMAC-SHA1.
struct TOTP: Sendable {
  let secret: Data
  var digits = 6
  var period: TimeInterval = 30

  func code(at date: Date) -> String {
    var counter = UInt64(floor(date.timeIntervalSince1970 / period)).bigEndian
    let message = withUnsafeBytes(of: &counter) { Data($0) }
    let hash = Array(HMAC<Insecure.SHA1>.authenticationCode(for: message, using: SymmetricKey(data: secret)))
    let offset = Int(hash[hash.count - 1] & 0x0f)
    let truncated = (UInt32(hash[offset] & 0x7f) << 24)
      | (UInt32(hash[offset + 1]) << 16)
      | (UInt32(hash[offset + 2]) << 8)
      | UInt32(hash[offset + 3])
    let modulus = (0..<digits).reduce(UInt32(1)) { acc, _ in acc * 10 }
    let value = String(truncated % modulus)
    return String(repeating: "0", count: max(0, digits - value.count)) + value
  }

  /// The period window `[start, start + period)` that contains `date`.
  func window(containing date: Date) -> DateInterval {
    let start = floor(date.timeIntervalSince1970 / period) * period
    return DateInterval(start: Date(timeIntervalSince1970: start), duration: period)
  }
}
