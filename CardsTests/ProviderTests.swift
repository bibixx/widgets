import Foundation
import Testing
@testable import Cards

struct ProviderTests {
  let now = Date(timeIntervalSince1970: 1_790_000_017)

  @Test func rawCardIsOneEntryNever() {
    let (entries, policy) = CardTimeline.entries(for: CardPreviewFixtures.rossmann, cardCount: 1, requestedID: nil, now: now)
    #expect(entries.count == 1)
    #expect(entries[0].state == .ok)
    #expect(policy == .never)
  }

  @Test func zappkaIs121AlignedEntries() {
    let (entries, policy) = CardTimeline.entries(for: CardPreviewFixtures.zappka, cardCount: 1, requestedID: nil, now: now)
    #expect(entries.count == 121)
    #expect(policy == .atEnd)
    #expect(entries[0].date <= now)
    #expect(now.timeIntervalSince(entries[0].date) < 30)
    #expect(entries.allSatisfy { $0.date.timeIntervalSince1970.truncatingRemainder(dividingBy: 30) == 0 })
    let codes = Set(entries.compactMap { Zappka.code(for: CardPreviewFixtures.zappka.zappkaCredentials!, at: $0.date) })
    #expect(codes.count > 100, "each entry renders a different code")
  }

  @Test func zappkaWithoutSecretNeedsSecret() {
    let (entries, _) = CardTimeline.entries(for: CardPreviewFixtures.missingSecret, cardCount: 1, requestedID: nil, now: now)
    #expect(entries.map(\.state) == [.needsSecret])
  }

  @Test func unknownIDIsDeleted() {
    let (entries, _) = CardTimeline.entries(for: nil, cardCount: 3, requestedID: UUID(), now: now)
    #expect(entries.map(\.state) == [.deleted])
  }

  @Test func noCards() {
    let (entries, _) = CardTimeline.entries(for: nil, cardCount: 0, requestedID: nil, now: now)
    #expect(entries.map(\.state) == [.noCards])
  }

  @Test @MainActor func zappkaEntryRendersItsOwnPayload() throws {
    let (entries, _) = CardTimeline.entries(for: CardPreviewFixtures.zappka, cardCount: 1, requestedID: nil, now: now)
    let entry = entries[5]
    let image = try #require(CardViewRenderTests.render(entry.card!, family: .medium, size: CardViewRenderTests.medium, date: entry.date))
    let expected = Zappka.payload(for: CardPreviewFixtures.zappka.zappkaCredentials!, at: entry.date)
    #expect(BarcodeDecoder.decode(image).contains { $0 == expected })
  }
}
