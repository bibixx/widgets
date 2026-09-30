import Foundation

/// What a Żappka card needs to produce its rotating code. Anything that produces
/// these (typing, pasting, a future Żabka login) can fill a card.
struct ZappkaCredentials: Codable, Hashable, Sendable {
  var userId: String
  /// Normalised: whitespace stripped, lowercased.
  var secretHex: String

  init(userId: String, secretHex: String) {
    self.userId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
    self.secretHex = Self.normalizeSecret(secretHex)
  }

  enum Issue: Equatable, Sendable {
    case missingUserId, missingSecret, secretNotHex, secretOddLength
    case secretShort, userIdUnusualCharacters

    var isError: Bool {
      switch self {
      case .secretShort, .userIdUnusualCharacters: false
      default: true
      }
    }

    var message: String {
      switch self {
      case .missingUserId: "Enter your User ID"
      case .missingSecret: "Enter your secret"
      case .secretNotHex: "The secret must be hexadecimal (0–9, a–f)"
      case .secretOddLength: "The secret must have an even number of characters"
      case .secretShort: "This secret looks short — double-check it"
      case .userIdUnusualCharacters: "The User ID usually contains only letters, digits, - and _"
      }
    }
  }

  static func normalizeSecret(_ raw: String) -> String {
    String(raw.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }).lowercased()
  }

  func validate() -> [Issue] {
    var issues: [Issue] = []
    if userId.isEmpty {
      issues.append(.missingUserId)
    } else if !userId.unicodeScalars.allSatisfy(Self.userIdCharacters.contains) {
      issues.append(.userIdUnusualCharacters)
    }
    if secretHex.isEmpty {
      issues.append(.missingSecret)
    } else if !secretHex.allSatisfy(\.isHexDigit) {
      issues.append(.secretNotHex)
    } else if !secretHex.count.isMultiple(of: 2) {
      issues.append(.secretOddLength)
    } else if secretHex.count < 40 {
      issues.append(.secretShort)
    }
    return issues
  }

  var isValid: Bool { !validate().contains(where: \.isError) }

  /// Hex → bytes, or nil if the secret isn't valid hex.
  var secretData: Data? {
    guard !secretHex.isEmpty, secretHex.count.isMultiple(of: 2), secretHex.allSatisfy(\.isHexDigit) else { return nil }
    var data = Data(capacity: secretHex.count / 2)
    var index = secretHex.startIndex
    while index < secretHex.endIndex {
      let next = secretHex.index(index, offsetBy: 2)
      guard let byte = UInt8(secretHex[index..<next], radix: 16) else { return nil }
      data.append(byte)
      index = next
    }
    return data
  }

  private static let userIdCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-")
}
