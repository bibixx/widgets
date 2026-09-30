import SwiftUI
import WidgetKit

/// The one visual for a card: widgets, the card list and the editor's live preview.
/// Design: see CardLayout (ported from the old widgets renderer, in points).
struct CardView: View {
  let card: CardSnapshot
  let family: CardFamily
  /// The moment to render (timeline entry date / TimelineView tick). Never `Date()` inside.
  let date: Date
  var renderingMode: CardRenderingMode = .fullColor

  var body: some View {
    GeometryReader { proxy in
      let metrics = CardLayout.metrics(for: family, size: proxy.size, symbology: card.symbology, logo: card.logo)
      ZStack(alignment: .topLeading) {
        header(metrics)
        CodeArea(card: card, code: CardCode.resolve(card, at: date), metrics: metrics, renderingMode: renderingMode)
      }
    }
    .background(bodyBackground)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
  }

  // MARK: Header

  private func header(_ metrics: CardLayout.Metrics) -> some View {
    ZStack(alignment: .leading) {
      headerFill
        .widgetAccentable()
      HStack(spacing: 8) {
        LogoView(logo: card.logo)
          .frame(maxWidth: metrics.logoMaxSize.width, alignment: logoAlignment)
          .frame(height: metrics.logoMaxSize.height)
          .frame(maxWidth: centersLogo ? .infinity : nil, alignment: .center)
        if !centersLogo { Spacer(minLength: 0) }
      }
      .padding(.leading, centersLogo ? 0 : metrics.logoLeading)
      .padding(.trailing, metrics.headerTrailing)
      .padding(.horizontal, centersLogo ? metrics.logoLeading : 0)
    }
    .frame(width: metrics.size.width, height: metrics.headerHeight)
  }

  @ViewBuilder private var headerFill: some View {
    switch renderingMode {
    case .fullColor: LinearGradient(colors: [card.color1, card.color2], startPoint: .top, endPoint: .bottom)
    case .accented: Color.accentPreviewTint
    case .vibrant: Color.white.opacity(0.28)
    }
  }

  @ViewBuilder private var bodyBackground: some View {
    switch renderingMode {
    case .fullColor: Color.white
    // In tinted/clear modes the system removes the widget's background; only the code plate stays white.
    case .accented, .vibrant: Color.clear
    }
  }

  /// Small widgets centre the logo, like the original small cards.
  private var centersLogo: Bool { family == .small }
  private var logoAlignment: Alignment { centersLogo ? .center : .leading }

  private var accessibilityLabel: String {
    card.isZappka ? "\(card.name) card, rotating code" : "\(card.name) card, \(card.symbology.displayName)"
  }
}

extension Color {
  /// Stand-in for the Home Screen tint when previewing the tinted mode.
  static let accentPreviewTint = Color(red: 0.55, green: 0.7, blue: 0.95)
}

struct LogoView: View {
  let logo: CardLogo

  var body: some View {
    switch logo {
    case .none:
      Color.clear.frame(width: 0, height: 0)
    case .preset(let name):
      Image(name).resizable().scaledToFit()
    case .custom(let data):
      if let image = LogoCache.image(for: data) {
        Image(uiImage: image).resizable().scaledToFit()
      }
    }
  }
}

enum LogoCache {
  nonisolated(unsafe) private static let cache = NSCache<NSData, UIImage>()

  static func image(for data: Data) -> UIImage? {
    if let hit = cache.object(forKey: data as NSData) { return hit }
    guard let image = UIImage(data: data) else { return nil }
    cache.setObject(image, forKey: data as NSData)
    return image
  }
}

#Preview("Medium", traits: .fixedLayout(width: 338, height: 158)) {
  CardView(card: CardPreviewFixtures.rossmann, family: .medium, date: CardPreviewFixtures.fixedDate)
}

#Preview("All presets") {
  ScrollView {
    VStack(spacing: 16) {
      ForEach(CardPreviewFixtures.all) { card in
        HStack(spacing: 16) {
          CardView(card: card, family: .small, date: .now).frame(width: 158, height: 158)
          CardView(card: card, family: .medium, date: .now).frame(width: 338, height: 158)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
      }
    }
    .padding()
  }
  .background(Color.gray)
}

#Preview("Tinted", traits: .fixedLayout(width: 338, height: 158)) {
  CardView(card: CardPreviewFixtures.empik, family: .medium, date: .now, renderingMode: .accented)
    .background(Color.indigo)
}
