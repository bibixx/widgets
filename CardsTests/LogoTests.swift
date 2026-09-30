import Testing
import UIKit
@testable import Cards

/// WidgetKit refuses to archive a widget holding an image over ~1.07 MP and shows the
/// placeholder instead, so every logo must stay well under that.
@MainActor
struct LogoTests {
  static let widgetImageLimit: CGFloat = 1_000_000

  @Test(arguments: Presets.logoNames)
  func presetLogoFitsWidgets(_ name: String) throws {
    let image = try #require(UIImage(named: name))
    let pixels = image.size.width * image.scale * image.size.height * image.scale
    #expect(pixels < Self.widgetImageLimit, "\(name): \(Int(pixels)) px")
  }

  @Test func importCapsWideLogos() throws {
    let wide = UIGraphicsImageRenderer(size: CGSize(width: 4000, height: 500)).pngData { context in
      UIColor.red.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 4000, height: 500))
    }
    let data = try #require(LogoImport.downscaledPNG(wide))
    let image = try #require(UIImage(data: data))
    #expect(image.size.width * image.scale <= 960)
    #expect(image.size.height * image.scale <= 240)
  }
}
