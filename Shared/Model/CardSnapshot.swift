import Foundation
import SwiftUI

/// A value copy of a card (plus its resolved secret): what views and widget entries render.
/// Decoupled from the SwiftData object, which isn't Sendable.
struct CardSnapshot: Hashable, Sendable, Identifiable {
  var id: UUID
  var name: String
  var presetID: String?
  /// The code type to draw. For a stored card this is the horizontal type; `rendered(for:)`
  /// swaps in the square one for square families.
  var symbology: Symbology
  var squareSymbology: Symbology
  var content: CardContent
  var zappkaSecret: String?
  var color1Hex: String
  var color2Hex: String
  var logo: CardLogo
  var showsCaption: Bool
  /// Editor preview: an empty number draws a faded sample instead of an error.
  var isPreview = false

  init(
    id: UUID = UUID(), name: String, presetID: String? = nil, symbology: Symbology, squareSymbology: Symbology = .qr, content: CardContent,
    zappkaSecret: String? = nil, color1Hex: String, color2Hex: String, logo: CardLogo,
    showsCaption: Bool = true, isPreview: Bool = false
  ) {
    self.id = id
    self.name = name
    self.presetID = presetID
    self.symbology = symbology
    self.squareSymbology = squareSymbology
    self.content = content
    self.zappkaSecret = zappkaSecret
    self.color1Hex = color1Hex
    self.color2Hex = color2Hex
    self.logo = logo
    self.showsCaption = showsCaption
    self.isPreview = isPreview
  }

  init(card: Card, zappkaSecret: String?) {
    self.init(
      id: card.id, name: card.name, presetID: card.presetID, symbology: card.symbology, squareSymbology: card.squareSymbology, content: card.content,
      zappkaSecret: zappkaSecret, color1Hex: card.color1Hex, color2Hex: card.color2Hex, logo: card.logo,
      showsCaption: card.showsCaption)
  }

  var color1: Color { Color(hex: color1Hex) }
  var color2: Color { Color(hex: color2Hex) }

  var isZappka: Bool { content.kind == .zappka }

  /// This card as drawn on `family`: its horizontal or square code type. Żappka's are fixed.
  func rendered(for family: CardFamily) -> CardSnapshot {
    var copy = self
    if isZappka {
      copy.symbology = family.isSquare ? Zappka.squareSymbology : Zappka.symbology
    } else if family.isSquare {
      copy.symbology = squareSymbology
    }
    return copy
  }

  var zappkaCredentials: ZappkaCredentials? {
    guard case .zappka(let userId) = content else { return nil }
    return ZappkaCredentials(userId: userId, secretHex: zappkaSecret ?? "")
  }
}
