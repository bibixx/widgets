import CoreGraphics
import Testing
@testable import Cards

struct CardLayoutTests {
  static let medium = CGSize(width: 338, height: 158)

  /// Old renderer px ÷ 3 (iPhone 13 Pro medium: 1014×474 px = 338×158 pt).
  @Test func mediumMatchesOldRenderer() {
    let m = CardLayout.metrics(for: .medium, size: Self.medium, symbology: .code128, logo: .preset("rossmann"))
    #expect(m.headerHeight == 40)
    #expect(m.codeArea == CGRect(x: 16, y: 56, width: 306, height: 86))
    #expect(abs(m.logoLeading - 64.0 / 3) < 0.001)
    #expect(m.logoMaxSize.height == 12)
    #expect(m.captionFontSize == 10 && m.captionTracking == 2.5)
    #expect(abs(m.notchHeight - 34.0 / 3) < 0.001)
    #expect(abs(m.notchWidth(characters: 13) - 448.0 / 3) < 0.001, "short captions get the min width")
  }

  @Test func smallMatchesOldRenderer() {
    let m = CardLayout.metrics(for: .small, size: CGSize(width: 158, height: 158), symbology: .code128, logo: .preset("empik"))
    #expect(abs(m.headerHeight - 88.0 / 3) < 0.001)
    #expect(m.codeArea.minX == 8 && abs(m.codeArea.minY - (88.0 / 3 + 8)) < 0.001)
    #expect(abs(m.logoMaxSize.height - (88.0 - 32) / 3) < 0.001, "64 px logo capped to the padded small header")
    #expect(m.notchMinWidth == 0)
  }

  @Test func largeUsesMediumValues() {
    let m = CardLayout.metrics(for: .large, size: CGSize(width: 338, height: 354), symbology: .qr)
    #expect(m.headerHeight == 40)
    #expect(m.codeArea == CGRect(x: 16, y: 56, width: 306, height: 282))
  }

  @Test(arguments: CardFamily.allCases)
  func sane(_ family: CardFamily) {
    let size: CGSize = switch family {
    case .small: CGSize(width: 158, height: 158)
    case .medium: Self.medium
    case .large: CGSize(width: 338, height: 354)
    }
    for symbology in Symbology.allCases {
      let m = CardLayout.metrics(for: family, size: size, symbology: symbology)
      let bounds = CGRect(origin: .zero, size: size)
      #expect(bounds.contains(m.codeArea))
      #expect(m.codeArea.width > 0 && m.codeArea.height > 0)
      #expect(m.codeArea.minY > m.headerHeight)
    }
  }

  @Test func codeRectFitting() {
    let area = CGRect(x: 0, y: 0, width: 300, height: 100)
    #expect(CardLayout.codeRect(in: area, symbology: .code128, matrixSize: CGSize(width: 90, height: 1)) == area)
    #expect(CardLayout.codeRect(in: area, symbology: .qr, matrixSize: CGSize(width: 21, height: 21)).size == CGSize(width: 100, height: 100))
    #expect(CardLayout.codeRect(in: area, symbology: .pdf417, matrixSize: CGSize(width: 120, height: 60)) == area, "PDF417 stretches to fill")
  }

  @Test func modulesFillTheWidthExactly() {
    let edges = CodeRaster.edges(count: 10, pixels: 35)
    #expect(edges.first == 0 && edges.last == 35)
    #expect(zip(edges, edges.dropFirst()).allSatisfy { [3, 4].contains($1 - $0) })
  }
}
