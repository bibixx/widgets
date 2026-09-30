import Foundation

/// Sample cards for previews and tests. Made-up numbers and a made-up Żappka secret only.
enum CardPreviewFixtures {
  static let fixedDate = Date(timeIntervalSince1970: 1_790_000_007)
  static let fakeZappkaSecret = "0f1e2d3c4b5a69788796a5b4c3d2e1f00a1b2c3d"

  static func card(_ preset: Preset, content: CardContent, symbology: Symbology? = nil, secret: String? = nil) -> CardSnapshot {
    CardSnapshot(
      name: preset.name, presetID: preset.id, symbology: symbology ?? preset.symbology, content: content,
      zappkaSecret: secret, color1Hex: preset.color1Hex, color2Hex: preset.color2Hex, logo: preset.logo)
  }

  static let zappka = card(Presets.zappka, content: .zappka(userId: "1234567"), secret: fakeZappkaSecret)
  static let zappkaBarcode = card(Presets.zappka, content: .raw("123456789012"), symbology: .code128)
  static let rossmann = card(Presets.rossmann, content: .raw("1234567890128"), symbology: .code128)
  static let empik = card(Presets.empik, content: .raw("0123456789012"), symbology: .code128)
  static let biedronka = card(Presets.biedronka, content: .raw("5901234123457"), symbology: .ean13)
  static let parkrun = card(Presets.parkrun, content: .raw("A1234567"), symbology: .code128)
  static let custom = card(Presets.custom, content: .raw("https://example.com/member/42"), symbology: .qr)
  static let missingSecret = card(Presets.zappka, content: .zappka(userId: "1234567"))
  static let invalid = card(Presets.rossmann, content: .raw("12345"), symbology: .ean13)

  static let all: [CardSnapshot] = [zappka, zappkaBarcode, rossmann, empik, biedronka, parkrun, custom]
}
