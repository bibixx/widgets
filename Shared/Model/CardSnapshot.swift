import Foundation
import SwiftUI

/// A value copy of a card (plus its resolved secret): what views and widget entries render.
/// Decoupled from the SwiftData object, which isn't Sendable.
struct CardSnapshot: Hashable, Sendable, Identifiable {
  var id: UUID
  var name: String
  var presetID: String?
  var symbology: Symbology
  var content: CardContent
  var zappkaSecret: String?
  var color1Hex: String
  var color2Hex: String
  var logo: CardLogo
  var showsCaption: Bool
  /// Editor preview: an empty number draws a faded sample instead of an error.
  var isPreview = false

  init(
    id: UUID = UUID(), name: String, presetID: String? = nil, symbology: Symbology, content: CardContent,
    zappkaSecret: String? = nil, color1Hex: String, color2Hex: String, logo: CardLogo,
    showsCaption: Bool = true, isPreview: Bool = false
  ) {
    self.id = id
    self.name = name
    self.presetID = presetID
    self.symbology = symbology
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
      id: card.id, name: card.name, presetID: card.presetID, symbology: card.symbology, content: card.content,
      zappkaSecret: zappkaSecret, color1Hex: card.color1Hex, color2Hex: card.color2Hex, logo: card.logo,
      showsCaption: card.showsCaption)
  }

  var color1: Color { Color(hex: color1Hex) }
  var color2: Color { Color(hex: color2Hex) }

  var isZappka: Bool { content.kind == .zappka }

  var zappkaCredentials: ZappkaCredentials? {
    guard case .zappka(let userId) = content else { return nil }
    return ZappkaCredentials(userId: userId, secretHex: zappkaSecret ?? "")
  }
}
