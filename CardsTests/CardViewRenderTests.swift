import CoreGraphics
import ImageIO
import SwiftUI
import Testing
import UniformTypeIdentifiers
@testable import Cards

@MainActor
struct CardViewRenderTests {
  static let medium = CGSize(width: 338, height: 158)

  static func render(_ card: CardSnapshot, family: CardFamily = .medium, size: CGSize = medium, mode: CardRenderingMode = .fullColor, date: Date = CardPreviewFixtures.fixedDate) -> CGImage? {
    let view = CardView(card: card, family: family, date: date, renderingMode: mode)
      .frame(width: size.width, height: size.height)
      .environment(\.displayScale, 3)
    let renderer = ImageRenderer(content: view)
    renderer.scale = 3
    return renderer.cgImage
  }

  static func dump(_ image: CGImage, _ name: String) {
    let dir = URL(fileURLWithPath: "/tmp/cards-render", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    guard let dest = CGImageDestinationCreateWithURL(dir.appendingPathComponent("\(name).png") as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
  }

  @Test func mediumZappkaPDF417Decodes() throws {
    let card = CardPreviewFixtures.zappka
    let image = try #require(Self.render(card))
    Self.dump(image, "zappka-medium")
    let expected = Zappka.payload(for: try #require(card.zappkaCredentials), at: CardPreviewFixtures.fixedDate)
    #expect(BarcodeDecoder.decode(image).contains { $0 == expected })
  }

  @Test(arguments: ["rossmann", "empik", "zappkaBarcode", "biedronka", "parkrun", "custom"])
  func everyFamilyDecodes(_ name: String) throws {
    let card = [
      "rossmann": CardPreviewFixtures.rossmann, "empik": CardPreviewFixtures.empik,
      "zappkaBarcode": CardPreviewFixtures.zappkaBarcode, "biedronka": CardPreviewFixtures.biedronka,
      "parkrun": CardPreviewFixtures.parkrun, "custom": CardPreviewFixtures.custom,
    ][name]!
    guard case .code(let text, _, _) = CardCode.resolve(card, at: CardPreviewFixtures.fixedDate) else {
      Issue.record("no code"); return
    }
    let sizes: [(CardFamily, CGSize)] = [(.small, CGSize(width: 158, height: 158)), (.medium, Self.medium), (.large, CGSize(width: 338, height: 354))]
    for (family, size) in sizes {
      for mode in [CardRenderingMode.fullColor, .accented] {
        let image = try #require(Self.render(card, family: family, size: size, mode: mode))
        Self.dump(image, "\(name)-\(family.rawValue)-\(mode.rawValue)")
        let decoded = BarcodeDecoder.decode(image)
        #expect(decoded.contains { BarcodeDecoder.matches($0, text: text, symbology: card.symbology) },
                "\(name) \(family) \(mode): \(decoded)")
      }
    }
  }

  @Test func problemStatesRender() throws {
    for card in [CardPreviewFixtures.missingSecret, CardPreviewFixtures.invalid] {
      for family in CardFamily.allCases {
        let size = family == .small ? CGSize(width: 158, height: 158) : family == .large ? CGSize(width: 338, height: 354) : Self.medium
        #expect(Self.render(card, family: family, size: size) != nil)
      }
    }
  }
}
