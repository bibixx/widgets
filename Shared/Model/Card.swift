import Foundation
import SwiftData
import SwiftUI

typealias Card = CardsSchemaV2.Card

/// Frozen: the shape builds 1–3 shipped with. Don't edit; add a new schema version instead.
enum CardsSchemaV1: VersionedSchema {
  static let versionIdentifier = Schema.Version(1, 0, 0)
  static var models: [any PersistentModel.Type] { [Card.self] }

  @Model
  final class Card {
    @Attribute(.unique) var id: UUID
    var name: String
    var presetID: String?
    var symbologyRaw: String
    var squareSymbologyRaw: String
    var contentKind: String
    var rawData: String
    var zappkaUserId: String
    var color1Hex: String
    var color2Hex: String
    var logoKind: String
    var logoPresetName: String?
    @Attribute(.externalStorage) var logoImageData: Data?
    var showsCaption: Bool
    var tapURL: String?
    var sortIndex: Int
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID, createdAt: Date) {
      self.id = id
      self.name = ""
      self.presetID = nil
      self.symbologyRaw = Symbology.code128.rawValue
      self.squareSymbologyRaw = Symbology.qr.rawValue
      self.contentKind = CardContent.Kind.raw.rawValue
      self.rawData = ""
      self.zappkaUserId = ""
      self.color1Hex = "#ff00ff"
      self.color2Hex = "#ff0000"
      self.logoKind = CardLogo.Kind.none.rawValue
      self.logoPresetName = nil
      self.logoImageData = nil
      self.showsCaption = true
      self.tapURL = nil
      self.sortIndex = 0
      self.createdAt = createdAt
      self.updatedAt = createdAt
    }
  }
}

/// V2: `zappkaPhone`, the number a Żappka card was signed in with.
enum CardsSchemaV2: VersionedSchema {
  static let versionIdentifier = Schema.Version(2, 0, 0)
  static var models: [any PersistentModel.Type] { [Card.self] }

  /// Stored as primitives (SwiftData handles those most reliably); typed wrappers below.
  @Model
  final class Card {
    @Attribute(.unique) var id: UUID
    var name: String
    var presetID: String?
    /// Code type on the horizontal (medium) widget.
    var symbologyRaw: String
    /// Code type on the square (small, large) widgets.
    var squareSymbologyRaw: String
    var contentKind: String
    var rawData: String
    var zappkaUserId: String
    /// National digits (e.g. "505968488") of the number used to sign in to Żabka; labels the
    /// card instead of the opaque User ID. Nil for cards filled in any other way.
    var zappkaPhone: String?
    var color1Hex: String
    var color2Hex: String
    var logoKind: String
    var logoPresetName: String?
    @Attribute(.externalStorage) var logoImageData: Data?
    var showsCaption: Bool
    /// What tapping the widget opens (another app's deep link, a web page). Nil opens the editor.
    var tapURL: String?
    var sortIndex: Int
    var createdAt: Date
    var updatedAt: Date

    init(
      id: UUID = UUID(),
      name: String = "",
      presetID: String? = nil,
      symbology: Symbology = .code128,
      squareSymbology: Symbology = .qr,
      content: CardContent = .raw(""),
      color1Hex: String = "#ff00ff",
      color2Hex: String = "#ff0000",
      logo: CardLogo = .none,
      showsCaption: Bool = true,
      tapURL: String? = nil,
      sortIndex: Int = 0,
      createdAt: Date = .now
    ) {
      self.id = id
      self.name = name
      self.presetID = presetID
      self.symbologyRaw = symbology.rawValue
      self.squareSymbologyRaw = squareSymbology.rawValue
      self.contentKind = CardContent.Kind.raw.rawValue
      self.rawData = ""
      self.zappkaUserId = ""
      self.zappkaPhone = nil
      self.color1Hex = color1Hex
      self.color2Hex = color2Hex
      self.logoKind = CardLogo.Kind.none.rawValue
      self.logoPresetName = nil
      self.logoImageData = nil
      self.showsCaption = showsCaption
      self.tapURL = tapURL
      self.sortIndex = sortIndex
      self.createdAt = createdAt
      self.updatedAt = createdAt
      self.content = content
      self.logo = logo
    }
  }
}

extension Card {
  var symbology: Symbology {
    get { Symbology(rawValue: symbologyRaw) ?? .pdf417 }
    set { symbologyRaw = newValue.rawValue }
  }

  var squareSymbology: Symbology {
    get { Symbology(rawValue: squareSymbologyRaw) ?? .qr }
    set { squareSymbologyRaw = newValue.rawValue }
  }

  /// Setting the content keeps the other kind's field, so switching back and forth
  /// in the editor doesn't lose what was typed.
  var content: CardContent {
    get {
      switch CardContent.Kind(rawValue: contentKind) ?? .raw {
      case .raw: .raw(rawData)
      case .zappka: .zappka(userId: zappkaUserId)
      }
    }
    set {
      contentKind = newValue.kind.rawValue
      switch newValue {
      case .raw(let text): rawData = text
      case .zappka(let userId): zappkaUserId = userId
      }
    }
  }

  var logo: CardLogo {
    get {
      switch CardLogo.Kind(rawValue: logoKind) ?? .none {
      case .none: .none
      case .preset: logoPresetName.map(CardLogo.preset) ?? .none
      case .custom: logoImageData.map(CardLogo.custom) ?? .none
      }
    }
    set {
      logoKind = newValue.kind.rawValue
      switch newValue {
      case .none: break
      case .preset(let name): logoPresetName = name
      case .custom(let data): logoImageData = data
      }
    }
  }

  /// How the list and the widget picker identify a Żappka card: the sign-in number, else the User ID.
  var zappkaAccountLabel: String {
    zappkaPhone.map { "+48 \(Zappka.formatPhone($0))" } ?? zappkaUserId
  }

  var color1: Color { Color(hex: color1Hex) }
  var color2: Color { Color(hex: color2Hex) }

  func snapshot(secrets: SecretStore = SecretStore()) -> CardSnapshot {
    let secret: String? = if case .zappka = content { try? secrets.zappkaSecret(for: id) } else { nil }
    return CardSnapshot(card: self, zappkaSecret: secret)
  }
}

enum CardsMigrationPlan: SchemaMigrationPlan {
  static var schemas: [any VersionedSchema.Type] { [CardsSchemaV1.self, CardsSchemaV2.self] }
  static var stages: [MigrationStage] {
    [.lightweight(fromVersion: CardsSchemaV1.self, toVersion: CardsSchemaV2.self)]
  }
}
