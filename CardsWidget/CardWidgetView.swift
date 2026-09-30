import SwiftUI
import WidgetKit

struct CardWidgetView: View {
  let entry: CardEntry
  @Environment(\.widgetFamily) private var widgetFamily
  @Environment(\.widgetRenderingMode) private var widgetRenderingMode

  var body: some View {
    content
      .containerBackground(.white, for: .widget)
      .widgetURL(entry.card.map { DeepLink.card($0.id, edit: entry.state == .needsSecret) } ?? URL(string: "cards://")!)
  }

  @ViewBuilder private var content: some View {
    switch entry.state {
    case .ok:
      if let card = entry.card {
        CardView(
          card: card, family: family, date: entry.date, renderingMode: renderingMode,
          headerAccessory: showsRefresh(card) ? AnyView(refreshButton) : nil)
      }
    case .noCards:
      message("Open Cards to add a card", symbol: "plus.rectangle.on.rectangle")
    case .deleted:
      message("Card removed — edit widget", symbol: "questionmark.square.dashed")
    case .needsSecret:
      if let card = entry.card {
        // Header stays recognisable; the code area explains what's missing.
        CardView(card: card, family: family, date: entry.date, renderingMode: renderingMode, showsCountdown: false)
      }
    }
  }

  private func showsRefresh(_ card: CardSnapshot) -> Bool {
    card.isZappka && widgetFamily != .systemSmall
  }

  private var refreshButton: some View {
    Button(intent: RefreshIntent()) {
      Image(systemName: "arrow.clockwise")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.white.opacity(0.66))
    }
    .buttonStyle(.plain)
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
