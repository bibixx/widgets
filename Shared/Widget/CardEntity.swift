import AppIntents
import Foundation
import SwiftData

/// A card as the "Edit widget" picker sees it. Compiled into the app and the widget.
struct CardEntity: AppEntity {
  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Card"
  static let defaultQuery = CardEntityQuery()

  let id: UUID
  let name: String
  let detail: String

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(name)", subtitle: "\(detail)")
  }

  init(id: UUID, name: String, detail: String) {
    self.id = id
    self.name = name
    self.detail = detail
  }

  init(card: Card) {
    self.init(
      id: card.id, name: card.name,
      detail: card.content.kind == .zappka ? card.zappkaUserId : card.rawData)
  }
}

struct CardEntityQuery: EntityQuery {
  func entities(for identifiers: [UUID]) async throws -> [CardEntity] {
    try await MainActor.run {
      try Self.allCards().filter { identifiers.contains($0.id) }
    }
  }

  func suggestedEntities() async throws -> [CardEntity] {
    try await MainActor.run { try Self.allCards() }
  }

  /// A freshly added widget shows the first card instead of an empty state.
  func defaultResult() async -> CardEntity? {
    await MainActor.run { try? Self.allCards().first }
  }

  @MainActor
  private static func allCards() throws -> [CardEntity] {
    let container = try SharedStore.makeContainer()
    return try SharedStore.fetchCards(in: container.mainContext).map(CardEntity.init(card:))
  }
}

struct SelectCardIntent: WidgetConfigurationIntent {
  static let title: LocalizedStringResource = "Choose card"
  static let description = IntentDescription("Pick which card this widget shows.")

  @Parameter(title: "Card")
  var card: CardEntity?

  init() {}
  init(card: CardEntity?) { self.card = card }
}
