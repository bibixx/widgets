import CoreGraphics
import UIKit

enum CardFamily: String, CaseIterable, Identifiable, Sendable {
  case small, medium, large
  var id: String { rawValue }
  var displayName: String {
    switch self {
    case .small: "Small"
    case .medium: "Medium"
    case .large: "Large"
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

/// The widget design, ported from the old widgets renderer (widgets/app/api/og/{route,Code}.tsx).
/// That renderer laid out in CSS px at the device's 3× resolution, so every size here is
/// its px value ÷ 3, in points, the same on every device. Its 6 px outline is left out:
/// the Liquid Glass Home Screen already highlights widget edges.
enum CardLayout {
  enum Style {
    static let headerHeight: CGFloat = 40                 // 120 px
    static let smallHeaderHeight: CGFloat = 88.0 / 3      // 88 px
    static let headerPaddingV: CGFloat = 16.0 / 3         // 16 px
    static let headerPaddingH: CGFloat = 64.0 / 3         // 64 px
    static let smallHeaderPaddingH: CGFloat = 16.0 / 3    // 16 px
    /// `iconHeight ?? 64` px; some presets set their own.
    static let logoHeight: CGFloat = 64.0 / 3
    static let presetLogoHeights: [String: CGFloat] = ["zappka": 88.0 / 3, "rossmann": 36.0 / 3, "biedronka": 48.0 / 3]
    static let codeInset: CGFloat = 16                    // container padding 48 px
    static let smallCodeInset: CGFloat = 8                // 24 px
    /// Linear/PDF417 `borderRadius: 40px / 32px` (elliptical).
    static let codeCornerSize = CGSize(width: 40.0 / 3, height: 32.0 / 3)
    /// QR/DataMatrix/Aztec `borderRadius: 8px`.
    static let squareCornerRadius: CGFloat = 8.0 / 3
    /// SF Mono 30 px, `letterSpacing: .25em`.
    static let captionFontSize: CGFloat = 10
    static let captionTracking: CGFloat = 2.5
    /// Caption ink bottom sits 2 px above the code's bottom edge.
    static let captionBaseline: CGFloat = 2.0 / 3
    /// White caption box: `paddingTop 12` + line height `.75em` (measured 34 px).
    static let notchHeight: CGFloat = 34.0 / 3
    static let notchSidePadding: CGFloat = 8                // 24 px
    static let smallNotchSidePadding: CGFloat = 8.0 / 3     // 8 px
    static let notchMinWidth: CGFloat = 448.0 / 3           // not on small
    static let notchTopRadius: CGFloat = 4.0 / 3
  }

  struct Metrics: Equatable, Sendable {
    var size: CGSize
    var headerHeight: CGFloat
    var logoLeading: CGFloat
    var logoMaxSize: CGSize
    var headerTrailing: CGFloat
    /// The padded box the code fills (linear/PDF417) or is centred in (2D).
    var codeArea: CGRect
    var codeInset: CGFloat
    var captionFontSize: CGFloat
    var captionTracking: CGFloat
    var captionBaseline: CGFloat
    /// Distance from the code's bottom edge up to the caption box top.
    var notchHeight: CGFloat
    var notchSidePadding: CGFloat
    var notchMinWidth: CGFloat
    var notchTopRadius: CGFloat

    /// The caption's width for `count` characters, trailing letter-spacing included
    /// (the old renderer centred it that way).
    func captionWidth(characters count: Int) -> CGFloat {
      CGFloat(count) * (CardLayout.monospacedAdvance(fontSize: captionFontSize) + captionTracking)
    }

    /// The white caption box's width.
    func notchWidth(characters count: Int) -> CGFloat {
      max(notchMinWidth, captionWidth(characters: count) + 2 * notchSidePadding)
    }
  }

  static func logoHeight(for logo: CardLogo) -> CGFloat {
    if case .preset(let name) = logo, let height = Style.presetLogoHeights[name] { return height }
    return Style.logoHeight
  }

  static func metrics(for family: CardFamily, size: CGSize, symbology: Symbology, logo: CardLogo = .none) -> Metrics {
    let isSmall = family == .small
    let header = isSmall ? Style.smallHeaderHeight : Style.headerHeight
    let padH = isSmall ? Style.smallHeaderPaddingH : Style.headerPaddingH
    let inset = isSmall ? Style.smallCodeInset : Style.codeInset
    // The logo keeps its iconHeight; on the small header it can't exceed the padded height.
    let logoHeight = min(logoHeight(for: logo), header - 2 * Style.headerPaddingV)

    let codeArea = CGRect(
      x: inset, y: header + inset,
      width: max(0, size.width - 2 * inset),
      height: max(0, size.height - header - 2 * inset))

    return Metrics(
      size: size,
      headerHeight: header,
      logoLeading: padH,
      logoMaxSize: CGSize(width: max(0, size.width - 2 * padH), height: logoHeight),
      headerTrailing: padH,
      codeArea: codeArea,
      codeInset: inset,
      captionFontSize: Style.captionFontSize,
      captionTracking: Style.captionTracking,
      captionBaseline: Style.captionBaseline,
      notchHeight: Style.notchHeight,
      notchSidePadding: isSmall ? Style.smallNotchSidePadding : Style.notchSidePadding,
      notchMinWidth: isSmall ? 0 : Style.notchMinWidth,
      notchTopRadius: Style.notchTopRadius)
  }

  /// Linear and PDF417 codes are clipped with the elliptical corners; square ones with 8 px.
  static func codeCornerSize(for symbology: Symbology) -> CGSize {
    symbology.kind == .twoD
      ? CGSize(width: Style.squareCornerRadius, height: Style.squareCornerRadius)
      : Style.codeCornerSize
  }

  /// Where the code itself sits inside `codeArea`, given its module matrix size.
  static func codeRect(in area: CGRect, symbology: Symbology, matrixSize: CGSize) -> CGRect {
    guard matrixSize.width > 0, matrixSize.height > 0, area.width > 0, area.height > 0 else { return area }
    switch symbology.kind {
    // Linear and PDF417 stretch to fill the box (`width/height: 100%` in the old renderer).
    case .linear, .stacked:
      return area
    case .twoD:
      let side = min(area.width, area.height)
      return CGRect(x: area.midX - side / 2, y: area.midY - side / 2, width: side, height: side)
    }
  }

  /// Natural advance of one monospaced digit at `size`, for computing tracking.
  static func monospacedAdvance(fontSize: CGFloat) -> CGFloat {
    let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    return ("0" as NSString).size(withAttributes: [.font: font]).width
  }
}
