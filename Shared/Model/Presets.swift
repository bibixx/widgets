import Foundation

struct Preset: Identifiable, Hashable, Sendable {
  let id: String
  let name: String
  let color1Hex: String
  let color2Hex: String
  /// Asset name in Logos.xcassets.
  let logoName: String?
  let contentKind: CardContent.Kind
  let symbology: Symbology

  var logo: CardLogo { logoName.map(CardLogo.preset) ?? .none }

  /// Applies styling, content kind and code type. Keeps typed data (card number, User ID).
  func apply(to card: Card) {
    card.presetID = id
    card.color1Hex = color1Hex
    card.color2Hex = color2Hex
    card.logo = logo
    card.symbology = symbology
    switch contentKind {
    case .raw: card.content = .raw(card.rawData)
    case .zappka: card.content = .zappka(userId: card.zappkaUserId)
    }
  }
}

enum Presets {
  // PDF417 on the store presets is a placeholder until each real card's code type
  // is confirmed (open question Q1); the reference widgets look like Code 128.
  static let custom = Preset(id: "custom", name: "Custom", color1Hex: "#ff00ff", color2Hex: "#ff0000", logoName: nil, contentKind: .raw, symbology: .pdf417)
  static let zappka = Preset(id: "zappka", name: "Żappka", color1Hex: "#01B15B", color2Hex: "#00A335", logoName: "zappka", contentKind: .zappka, symbology: .pdf417)
  static let biedronka = Preset(id: "biedronka", name: "Biedronka", color1Hex: "#9a0100", color2Hex: "#ff0011", logoName: "biedronka", contentKind: .raw, symbology: .pdf417)
  static let rossmann = Preset(id: "rossmann", name: "Rossmann", color1Hex: "#C20225", color2Hex: "#A2021F", logoName: "rossmann", contentKind: .raw, symbology: .pdf417)
  static let parkrun = Preset(id: "parkrun", name: "parkrun", color1Hex: "#fea301", color2Hex: "#fe7e01", logoName: "parkrun", contentKind: .raw, symbology: .pdf417)
  static let empik = Preset(id: "empik", name: "Empik", color1Hex: "#2A2A2A", color2Hex: "#000000", logoName: "empik", contentKind: .raw, symbology: .pdf417)

  static let all: [Preset] = [zappka, biedronka, rossmann, parkrun, empik, custom]

  static func preset(id: String?) -> Preset? { all.first { $0.id == id } }

  /// Logo asset names, for the logo picker.
  static var logoNames: [String] { all.compactMap(\.logoName) }
}
