import SwiftUI
import WidgetKit

struct CardWidget: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(kind: WidgetReloader.kind, intent: SelectCardIntent.self, provider: Provider()) { entry in
      CardWidgetView(entry: entry)
    }
    .configurationDisplayName("Loyalty card")
    .description("Shows a card's barcode.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    // The header runs edge to edge.
    .contentMarginsDisabled()
  }
}

struct Provider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> CardEntry {
    CardEntry(date: .now, card: CardPreviewFixtures.zappka, state: .ok)
  }

  func snapshot(for configuration: SelectCardIntent, in context: Context) async -> CardEntry {
    let (card, _) = await CardTimeline.load(cardID: configuration.card?.id)
    return CardEntry(date: .now, card: card ?? CardPreviewFixtures.rossmann, state: .ok)
  }

  func timeline(for configuration: SelectCardIntent, in context: Context) async -> Timeline<CardEntry> {
    let requestedID = configuration.card?.id
    let (card, count) = await CardTimeline.load(cardID: requestedID)
    let (entries, policy) = CardTimeline.entries(for: card, cardCount: count, requestedID: requestedID, now: .now)
    return Timeline(entries: entries, policy: policy == .atEnd ? .atEnd : .never)
  }
}
