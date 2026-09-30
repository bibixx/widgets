import Foundation
import SwiftData
import WidgetKit

struct CardEntry: TimelineEntry {
  enum State: Equatable, Sendable { case ok, noCards, deleted, needsSecret }

  let date: Date
  let card: CardSnapshot?
  let state: State
}

/// Pure timeline logic (testable): which entries to hand WidgetKit for a card.
enum CardTimeline {
  /// How far ahead Żappka entries are precomputed. Tune in stage 8 if iOS drops long timelines.
  static let zappkaHorizon: TimeInterval = 60 * 60

  enum Policy: Equatable { case never, atEnd }

  static func entries(for card: CardSnapshot?, cardCount: Int, requestedID: UUID?, now: Date) -> ([CardEntry], Policy) {
    guard cardCount > 0 else { return ([CardEntry(date: now, card: nil, state: .noCards)], .never) }
    guard let card else {
      // A configured card that no longer exists.
      return ([CardEntry(date: now, card: nil, state: requestedID == nil ? .noCards : .deleted)], .never)
    }
    guard card.isZappka else { return ([CardEntry(date: now, card: card, state: .ok)], .never) }
    guard card.zappkaCredentials?.isValid == true else {
      return ([CardEntry(date: now, card: card, state: .needsSecret)], .never)
    }

    let start = Zappka.window(containing: now).start
    let count = Int(zappkaHorizon / Zappka.period) + 1
    let entries = (0..<count).map { i in
      CardEntry(date: start.addingTimeInterval(Double(i) * Zappka.period), card: card, state: .ok)
    }
    return (entries, .atEnd)
  }

  /// Loads the configured card (or the first one) from the shared store and Keychain.
  @MainActor
  static func load(cardID: UUID?, secrets: SecretStore = SecretStore()) -> (card: CardSnapshot?, count: Int) {
    guard let container = try? SharedStore.makeContainer() else { return (nil, 0) }
    let cards = (try? SharedStore.fetchCards(in: container.mainContext)) ?? []
    let card = cardID.map { id in cards.first { $0.id == id } } ?? cards.first
    return (card?.snapshot(secrets: secrets), cards.count)
  }
}
