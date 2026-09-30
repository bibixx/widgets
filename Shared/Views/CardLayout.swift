import CoreGraphics
import UIKit

enum CardFamily: String, CaseIterable, Identifiable, Sendable {
  case small, medium, large, fullscreen
  var id: String { rawValue }
  var displayName: String {
    switch self {
    case .small: "Small"
    case .medium: "Medium"
    case .large: "Large"
    case .fullscreen: "Fullscreen"
    }
  }
}

enum CardRenderingMode: String, CaseIterable, Identifiable, Sendable {
  case fullColor, accented, vibrant
  var id: String { rawValue }
  var displayName: String {
    switch self {
    case .fullColor: "Full colour"
    case .accented: "Tinted"
    case .vibrant: "Clear"
    }
  }
}

/// The widget design, measured from the user's cards (plans/reference, medium size).
/// All numbers are fractions of the *medium* widget's width (W) and height (H).
/// Structure and typography follow the old widgets renderer (widgets/app/api/og/Code.tsx):
/// SF Mono caption in a white box that sits on the code's bottom edge and cuts the bars.
enum CardLayout {
  enum Reference {
    /// Medium widget aspect (H / W) of the reference screenshots, 1395 / 2961.
    static let aspect: CGFloat = 1395.0 / 2961.0
    static let headerHeight: CGFloat = 0.241        // × H
    static let sideInset: CGFloat = 0.065           // × W, logo and code leading edge
    /// Logo height × header height. Default for custom logos and empik/parkrun; the old
    /// renderer gave some logos their own `iconHeight`, so those are calibrated per logo
    /// (Żappka, Rossmann measured; Biedronka from its iconHeight 48 vs the default 64).
    static let logoHeight: CGFloat = 0.578
    static let presetLogoHeights: [String: CGFloat] = ["zappka": 0.682, "rossmann": 0.332, "biedronka": 0.434]
    /// Vertical nudge × header height (negative = up); Żappka sits higher than centred.
    static let presetLogoOffsets: [String: CGFloat] = ["zappka": -0.048]
    static let logoMaxWidth: CGFloat = 0.5          // × W
    static let codeTop: CGFloat = 0.344             // × H
    static let codeBottom: CGFloat = 0.8968         // × H
    static let cornerRadius: CGFloat = 0.004        // × W
    static let captionCapHeight: CGFloat = 0.0473   // × H
    static let captionAdvance: CGFloat = 0.02363    // × W, per glyph
    static let captionBaseline: CGFloat = 0.0015    // × H above the code's bottom edge
    static let notchTop: CGFloat = 0.8301           // × H
    /// White notch box extends this far past the caption's glyph boxes on each side
    /// (≈0.031 W past the ink, measured).
    static let notchPadding: CGFloat = 0.027        // × W
  }

  struct Metrics: Equatable, Sendable {
    var size: CGSize
    var headerHeight: CGFloat
    var logoLeading: CGFloat
    var logoMaxSize: CGSize
    var logoOffsetY: CGFloat
    var countdownTrailing: CGFloat
    /// The area the code may occupy (linear codes fill it; 2D/stacked codes fit inside it).
    var codeArea: CGRect
    var cornerRadius: CGFloat
    var captionFontSize: CGFloat
    var captionAdvance: CGFloat
    var captionBaseline: CGFloat
    /// Distance from the code's bottom edge up to the notch top.
    var notchHeight: CGFloat
    var notchPadding: CGFloat

    /// The caption's glyph-box width for `count` characters.
    func captionWidth(characters count: Int) -> CGFloat { CGFloat(count) * captionAdvance }
  }

  /// The medium widget's size that `size` corresponds to, so every family keeps the same
  /// absolute header, inset and caption sizes as a medium widget on the same device.
  static func mediumReference(for family: CardFamily, size: CGSize) -> CGSize {
    switch family {
    case .medium: size
    case .small: CGSize(width: size.height / Reference.aspect, height: size.height)
    case .large, .fullscreen: CGSize(width: size.width, height: size.width * Reference.aspect)
    }
  }

  static func logoHeightFraction(for logo: CardLogo) -> CGFloat {
    if case .preset(let name) = logo, let fraction = Reference.presetLogoHeights[name] { return fraction }
    return Reference.logoHeight
  }

  static func logoOffsetFraction(for logo: CardLogo) -> CGFloat {
    if case .preset(let name) = logo { return Reference.presetLogoOffsets[name] ?? 0 }
    return 0
  }

  static func metrics(for family: CardFamily, size: CGSize, symbology: Symbology, logo: CardLogo = .none) -> Metrics {
    let m = mediumReference(for: family, size: size)
    let W = m.width, H = m.height
    let header = Reference.headerHeight * H
    let inset = Reference.sideInset * W
    let gapAbove = (Reference.codeTop - Reference.headerHeight) * H
    let gapBelow = (1 - Reference.codeBottom) * H

    let codeArea = CGRect(
      x: inset, y: header + gapAbove,
      width: max(0, size.width - 2 * inset),
      height: max(0, size.height - header - gapAbove - gapBelow))

    let capHeight = Reference.captionCapHeight * H
    let captionFontSize = capHeight / monospacedCapHeightRatio

    return Metrics(
      size: size,
      headerHeight: header,
      logoLeading: inset,
      logoMaxSize: CGSize(width: min(Reference.logoMaxWidth * W, size.width - 2 * inset), height: logoHeightFraction(for: logo) * header),
      logoOffsetY: logoOffsetFraction(for: logo) * header,
      countdownTrailing: inset,
      codeArea: codeArea,
      cornerRadius: Reference.cornerRadius * W,
      captionFontSize: captionFontSize,
      captionAdvance: Reference.captionAdvance * W,
      captionBaseline: Reference.captionBaseline * H,
      notchHeight: (Reference.codeBottom - Reference.notchTop) * H,
      notchPadding: Reference.notchPadding * W)
  }

  /// Where the code itself sits inside `codeArea`, given its module matrix size.
  static func codeRect(in area: CGRect, symbology: Symbology, matrixSize: CGSize) -> CGRect {
    guard matrixSize.width > 0, matrixSize.height > 0, area.width > 0, area.height > 0 else { return area }
    switch symbology.kind {
    case .linear:
      return area
    case .twoD:
      let side = min(area.width, area.height)
      return CGRect(x: area.midX - side / 2, y: area.midY - side / 2, width: side, height: side)
    case .stacked:
      let scale = min(area.width / matrixSize.width, area.height / matrixSize.height)
      let w = matrixSize.width * scale, h = matrixSize.height * scale
      return CGRect(x: area.midX - w / 2, y: area.midY - h / 2, width: w, height: h)
    }
  }

  static let monospacedCapHeightRatio: CGFloat = UIFont.monospacedSystemFont(ofSize: 100, weight: .regular).capHeight / 100

  /// Natural advance of one monospaced digit at `size`, for computing tracking.
  static func monospacedAdvance(fontSize: CGFloat) -> CGFloat {
    let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    return ("0" as NSString).size(withAttributes: [.font: font]).width
  }
}
