import Foundation

struct Preset: Identifiable, Hashable, Sendable {
  let id: String
  let name: String
  let color1Hex: String
  let color2Hex: String
  /// Asset name in Logos.xcassets.
  let logoName: String?
  let contentKind: CardContent.Kind
  /// Code type on the horizontal (medium) widget.
  let symbology: Symbology
  /// Code type on the square (small, large) widgets.
  var squareSymbology: Symbology = .qr
  /// Default for what tapping the widget opens: a universal link the store's app claims (its
  /// `apple-app-site-association`). Without the app installed it opens the website instead.
  var appURL: String? = nil

  var logo: CardLogo { logoName.map(CardLogo.preset) ?? .none }

  /// Applies styling, content kind and code type. Keeps typed data (card number, User ID).
  func apply(to card: Card) {
    let previous = Presets.preset(id: card.presetID)
    card.presetID = id
    card.color1Hex = color1Hex
    card.color2Hex = color2Hex
    card.logo = logo
    card.symbology = symbology
    card.squareSymbology = squareSymbology
    // A link the user typed stays; one that came from the old preset follows the new one.
    if card.tapURL == nil || card.tapURL == previous?.appURL { card.tapURL = appURL }
    switch contentKind {
    case .raw: card.content = .raw(card.rawData)
    case .zappka: card.content = .zappka(userId: card.zappkaUserId)
    }
  }
}

enum Presets {
  // Rossmann and Empik are Code 128 (the user's reference cards); parkrun barcodes are
  // Code 128 as standard. Biedronka's PDF417 is a placeholder until confirmed (Q1).
  // App links come from each domain's AASA file on Apple's CDN
  // (https://app-site-association.cdn-apple.com/a/v1/<domain>). Żappka's is an AppsFlyer OneLink
  // template (zappka.onelink.me, `/aGPw/*` → pl.zabka.apb2c). Biedronka and parkrun publish none.
  // Lidl Plus: Code 128 per the "Adding a preset" guide, not yet checked against a real card.
  static let custom = Preset(id: "custom", name: "Custom", color1Hex: "#ff00ff", color2Hex: "#ff0000", logoName: nil, contentKind: .raw, symbology: .code128)
  static let zappka = Preset(id: "zappka", name: "Żappka", color1Hex: "#01B15B", color2Hex: "#00A335", logoName: "zappka", contentKind: .zappka, symbology: Zappka.symbology, squareSymbology: Zappka.squareSymbology, appURL: "https://zappka.onelink.me/aGPw/")
  static let biedronka = Preset(id: "biedronka", name: "Biedronka", color1Hex: "#9a0100", color2Hex: "#ff0011", logoName: "biedronka", contentKind: .raw, symbology: .pdf417)
  static let rossmann = Preset(id: "rossmann", name: "Rossmann", color1Hex: "#C20225", color2Hex: "#A2021F", logoName: "rossmann", contentKind: .raw, symbology: .code128, appURL: "https://www.rossmann.pl/")
  static let parkrun = Preset(id: "parkrun", name: "parkrun", color1Hex: "#fea301", color2Hex: "#fe7e01", logoName: "parkrun", contentKind: .raw, symbology: .code128)
  static let empik = Preset(id: "empik", name: "Empik", color1Hex: "#2A2A2A", color2Hex: "#000000", logoName: "empik", contentKind: .raw, symbology: .code128, appURL: "https://www.empik.com/")
  static let lidl = Preset(id: "lidl", name: "Lidl Plus", color1Hex: "#0050AA", color2Hex: "#003F87", logoName: "lidl", contentKind: .raw, symbology: .code128, appURL: "https://www.lidlplus.com/")

  static let all: [Preset] = [zappka, biedronka, rossmann, parkrun, empik, lidl, custom]

  static func preset(id: String?) -> Preset? { all.first { $0.id == id } }

  /// Logo asset names, for the logo picker.
  static var logoNames: [String] { all.compactMap(\.logoName) }
}
