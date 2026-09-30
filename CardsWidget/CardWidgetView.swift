import AppIntents
import SwiftUI
import WidgetKit

struct CardWidgetView: View {
  let entry: CardEntry
  @Environment(\.widgetFamily) private var widgetFamily
  @Environment(\.widgetRenderingMode) private var widgetRenderingMode

  var body: some View {
    tappable
      .containerBackground(.white, for: .widget)
      .widgetURL(entry.card.map { DeepLink.card($0.id) } ?? URL(string: "cards://")!)
  }

  /// With a tap link, the whole widget is a button that opens it straight away (without
  /// launching Cards first). Otherwise, and while the card needs fixing, the tap opens the editor.
  @ViewBuilder private var tappable: some View {
    if entry.state == .ok, let url = entry.card?.tapURL {
      Button(intent: OpenTapLinkIntent(url: url)) {
        content.frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .buttonStyle(.plain)
    } else {
      content
    }
  }

  @ViewBuilder private var content: some View {
    switch entry.state {
    case .ok:
      if let card = entry.card {
        CardView(card: card, family: family, date: entry.date, renderingMode: renderingMode)
      }
    case .noCards:
      message("Open Cards to add a card", symbol: "plus.rectangle.on.rectangle")
    case .deleted:
      message("Card removed — edit widget", symbol: "questionmark.square.dashed")
    case .needsSecret:
      if let card = entry.card {
        // Header stays recognisable; the code area explains what's missing.
        CardView(card: card, family: family, date: entry.date, renderingMode: renderingMode)
      }
    }
  }

  private func message(_ text: String, symbol: String) -> some View {
    VStack(spacing: 8) {
      Image(systemName: symbol).font(.title2)
      Text(text).font(.footnote).multilineTextAlignment(.center)
    }
    .foregroundStyle(.secondary)
    .padding()
  }

  private var family: CardFamily {
    switch widgetFamily {
    case .systemSmall: .small
    case .systemLarge, .systemExtraLarge: .large
    default: .medium
    }
  }

  private var renderingMode: CardRenderingMode {
    switch widgetRenderingMode {
    case .accented: .accented
    case .vibrant: .vibrant
    default: .fullColor
    }
  }
}

#Preview(as: .systemMedium) {
  CardWidget()
} timeline: {
  CardEntry(date: CardPreviewFixtures.fixedDate, card: CardPreviewFixtures.zappka, state: .ok)
  CardEntry(date: CardPreviewFixtures.fixedDate, card: CardPreviewFixtures.rossmann, state: .ok)
}
