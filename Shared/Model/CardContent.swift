import Foundation

enum CardContent: Hashable, Sendable {
  case raw(String)
  /// The secret lives in `SecretStore`, keyed by the card's id.
  case zappka(userId: String)

  enum Kind: String, CaseIterable, Sendable { case raw, zappka }

  var kind: Kind {
    switch self {
    case .raw: .raw
    case .zappka: .zappka
    }
  }
}

enum CardLogo: Hashable, Sendable {
  case none
  case preset(String)
  case custom(Data)

  enum Kind: String, CaseIterable, Sendable { case none, preset, custom }

  var kind: Kind {
    switch self {
    case .none: .none
    case .preset: .preset
    case .custom: .custom
    }
  }
}
