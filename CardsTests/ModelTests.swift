import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import Cards

@MainActor
struct ModelTests {
  @Test func presetApplyKeepsData() {
    let card = Card(content: .raw("5901234123457"))
    Presets.rossmann.apply(to: card)
    #expect(card.presetID == "rossmann")
    #expect(card.color1Hex == "#C20225")
    #expect(card.logo == .preset("rossmann"))
    #expect(card.content == .raw("5901234123457"))

    Presets.zappka.apply(to: card)
    #expect(card.content == .zappka(userId: ""))
    #expect(card.symbology == .pdf417)
    Presets.empik.apply(to: card)
    #expect(card.content == .raw("5901234123457"), "switching back keeps the typed number")
  }

  @Test func roundTripThroughContainer() throws {
    let container = try SharedStore.makeContainer(inMemory: true)
    let context = container.mainContext
    let card = Card(name: "Empik", symbology: .code128, content: .raw("0491118882945"), sortIndex: 1)
    Presets.empik.apply(to: card)
    card.symbology = .code128
    context.insert(card)
    context.insert(Card(name: "First", sortIndex: 0))
    try context.save()

    let fetched = try SharedStore.fetchCards(in: context)
    #expect(fetched.map(\.name) == ["First", "Empik"])
    let found = try #require(try SharedStore.fetchCard(id: card.id, in: context))
    let snapshot = found.snapshot(secrets: SecretStore(service: "test.unused"))
    #expect(snapshot.symbology == .code128)
    #expect(snapshot.content == .raw("0491118882945"))
    #expect(snapshot.logo == .preset("empik"))
    #expect(snapshot.zappkaSecret == nil)
  }

  @Test(arguments: [
    ("", TapLink.Parsed.none),
    ("  ", .none),
    ("zappka://", .url(URL(string: "zappka://")!)),
    ("lidlplus://home", .url(URL(string: "lidlplus://home")!)),
    ("https://www.zabka.pl/app", .url(URL(string: "https://www.zabka.pl/app")!)),
    (" zabka.pl ", .url(URL(string: "https://zabka.pl")!)),
    ("zabka.pl:8080", .url(URL(string: "https://zabka.pl:8080")!)),
    ("hello", .invalid),
    ("zabka pl", .invalid),
  ])
  func tapLinkParsing(text: String, expected: TapLink.Parsed) {
    #expect(TapLink.parse(text) == expected)
  }

  @Test func presetApplyKeepsTypedTapURL() {
    let card = Card(content: .raw("1"), tapURL: "zappka://")
    Presets.rossmann.apply(to: card)
    #expect(card.tapURL == "zappka://")
    #expect(CardSnapshot(card: card, zappkaSecret: nil).tapURL == URL(string: "zappka://"))
  }

  @Test func presetTapURLFollowsPreset() {
    let card = Card(content: .raw("1"))
    Presets.lidl.apply(to: card)
    #expect(card.tapURL == Presets.lidl.appURL)
    Presets.rossmann.apply(to: card)
    #expect(card.tapURL == Presets.rossmann.appURL, "a preset's link follows the next preset")
    Presets.biedronka.apply(to: card)
    #expect(card.tapURL == nil)
  }

  @Test func presetAppURLsParse() {
    for preset in Presets.all {
      guard let appURL = preset.appURL else { continue }
      #expect(TapLink.parse(appURL) == .url(URL(string: appURL)!), "\(preset.id)")
    }
  }

  @Test func snapshotEquality() {
    let card = Card(name: "A", content: .raw("1"))
    #expect(CardSnapshot(card: card, zappkaSecret: nil) == CardSnapshot(card: card, zappkaSecret: nil))
    #expect(CardSnapshot(card: card, zappkaSecret: nil) != CardSnapshot(card: card, zappkaSecret: "ab"))
  }

  @Test func colorHex() {
    let rgb = try! #require(Color.rgb(hex: "#01B15B"))
    #expect(rgb.r == 1.0 / 255 && rgb.g == 177.0 / 255 && rgb.b == 91.0 / 255)
    #expect(Color(hex: "#01b15b").hexString == "#01b15b")
    #expect(Color.rgb(hex: "nope") == nil)
  }
}

struct SecretStoreTests {
  @Test func setGetOverwriteDelete() throws {
    let store = SecretStore(service: "io.legiec.cards.tests.\(UUID().uuidString)")
    let id = UUID()
    defer { try? store.setZappkaSecret(nil, for: id) }
    #expect(try store.zappkaSecret(for: id) == nil)
    try store.setZappkaSecret("00ff", for: id)
    #expect(try store.zappkaSecret(for: id) == "00ff")
    try store.setZappkaSecret("abcd", for: id)
    #expect(try store.zappkaSecret(for: id) == "abcd")
    try store.setZappkaSecret(nil, for: id)
    #expect(try store.zappkaSecret(for: id) == nil)
  }
}
