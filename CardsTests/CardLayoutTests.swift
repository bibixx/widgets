import CoreGraphics
import Testing
@testable import Cards

struct CardLayoutTests {
  static let medium = CGSize(width: 338, height: 158)

  @Test func mediumMatchesReference() {
    let m = CardLayout.metrics(for: .medium, size: Self.medium, symbology: .code128)
    let W = Self.medium.width, H = Self.medium.height
    #expect(abs(m.headerHeight / H - 0.241) < 0.001)
    #expect(abs(m.codeArea.minX / W - 0.065) < 0.001)
    #expect(abs(m.codeArea.maxX / W - 0.935) < 0.001)
    #expect(abs(m.codeArea.minY / H - 0.344) < 0.001)
    #expect(abs(m.codeArea.maxY / H - 0.8968) < 0.001)
    #expect(abs((m.codeArea.maxY - m.notchHeight) / H - 0.8301) < 0.001)
    #expect(abs(m.logoLeading / W - 0.065) < 0.001)
  }

  @Test(arguments: CardFamily.allCases)
  func sane(_ family: CardFamily) {
    let size: CGSize = switch family {
    case .small: CGSize(width: 158, height: 158)
    case .medium: Self.medium
    case .large: CGSize(width: 338, height: 354)
    case .fullscreen: CGSize(width: 393, height: 700)
    }
    for symbology in Symbology.allCases {
      let m = CardLayout.metrics(for: family, size: size, symbology: symbology)
      let bounds = CGRect(origin: .zero, size: size)
      #expect(bounds.contains(m.codeArea))
      #expect(m.codeArea.width > 0 && m.codeArea.height > 0)
      #expect(m.codeArea.minY > m.headerHeight)
    }
  }

  @Test func smallAndLargeKeepMediumAbsoluteSizes() {
    let medium = CardLayout.metrics(for: .medium, size: Self.medium, symbology: .code128)
    let small = CardLayout.metrics(for: .small, size: CGSize(width: 158, height: 158), symbology: .code128)
    let large = CardLayout.metrics(for: .large, size: CGSize(width: 338, height: 354), symbology: .code128)
    for other in [small, large] {
      #expect(abs(other.headerHeight - medium.headerHeight) < 0.5)
      #expect(abs(other.logoLeading - medium.logoLeading) < 0.5)
      #expect(abs(other.captionFontSize - medium.captionFontSize) < 0.2)
    }
  }

  @Test func codeRectFitting() {
    let area = CGRect(x: 0, y: 0, width: 300, height: 100)
    #expect(CardLayout.codeRect(in: area, symbology: .code128, matrixSize: CGSize(width: 90, height: 1)) == area)
    #expect(CardLayout.codeRect(in: area, symbology: .qr, matrixSize: CGSize(width: 21, height: 21)).size == CGSize(width: 100, height: 100))
    let pdf = CardLayout.codeRect(in: area, symbology: .pdf417, matrixSize: CGSize(width: 120, height: 60))
    #expect(pdf.size == CGSize(width: 200, height: 100))
  }

  @Test func wholePixelModulesWhenCheap() {
    #expect(CodeRaster.edges(count: 10, pixels: 35) == [2, 5, 8, 11, 14, 17, 20, 23, 26, 29, 32])
    let uneven = CodeRaster.edges(count: 10, pixels: 29)
    #expect(uneven.first == 0 && uneven.last == 29)
  }
}
