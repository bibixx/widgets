import Foundation
import SwiftData
import Testing
@testable import Cards

@MainActor
struct EditorDraftTests {
  let secrets = SecretStore(service: "io.legiec.cards.tests.\(UUID().uuidString)")

  @Test func newDraftSaveRoundTrips() throws {
    let container = try SharedStore.makeContainer(inMemory: true)
    let context = container.mainContext
    let draft = EditorDraft(preset: Presets.rossmann)
    draft.rawData = "590123412345"
    draft.symbology = .ean13
    draft.showsCaption = false
    let card = try draft.save(in: context, secrets: secrets)

    #expect(card.name == "Rossmann")
    #expect(card.rawData == "5901234123457", "check digit applied on save")
    #expect(card.symbology == .ean13)
    #expect(card.showsCaption == false)
    #expect(card.logo == .preset("rossmann"))

    let reloaded = EditorDraft(card: card, secret: nil)
    #expect(reloaded.rawData == "5901234123457")
    #expect(reloaded.color1Hex == Presets.rossmann.color1Hex)
  }

  @Test func zappkaSavesSecretToKeychainNotDB() throws {
    let container = try SharedStore.makeContainer(inMemory: true)
    let context = container.mainContext
    let draft = EditorDraft(preset: Presets.zappka)
    draft.zappkaUserId = " 1234567 "
    draft.zappkaSecret = CardPreviewFixtures.fakeZappkaSecret.uppercased()
    let card = try draft.save(in: context, secrets: secrets)
    defer { try? secrets.setZappkaSecret(nil, for: card.id) }

    #expect(card.content == .zappka(userId: "1234567"))
    #expect(card.symbology == .pdf417)
    #expect(try secrets.zappkaSecret(for: card.id) == CardPreviewFixtures.fakeZappkaSecret)
  }

  @Test func cancelChangesNothing() throws {
    let container = try SharedStore.makeContainer(inMemory: true)
    let context = container.mainContext
    let draft = EditorDraft(preset: Presets.empik)
    draft.rawData = "123"
    let card = try draft.save(in: context, secrets: secrets)

    let editing = EditorDraft(card: card, secret: nil)
    editing.rawData = "999"
    editing.apply(Presets.biedronka)
    // Dismissed without save.
    #expect(card.rawData == "123")
    #expect(card.presetID == "empik")
  }

  @Test func presetSwitchKeepsData() {
    let draft = EditorDraft(preset: Presets.rossmann)
    draft.rawData = "0491118882945"
    draft.apply(Presets.empik)
    #expect(draft.rawData == "0491118882945")
    #expect(draft.name == "Empik", "untouched name follows the preset")
    draft.name = "My card"
    draft.apply(Presets.rossmann)
    #expect(draft.name == "My card", "a custom name is kept")
  }

  @Test func zappkaForcesPDF417() {
    let draft = EditorDraft(preset: Presets.custom)
    draft.symbology = .qr
    draft.setContentKind(.zappka)
    #expect(draft.symbology == .pdf417)
    #expect(draft.snapshot().symbology == .pdf417)
  }

  @Test func errorsBlockSave() {
    let draft = EditorDraft(preset: Presets.biedronka)
    draft.symbology = .ean13
    draft.rawData = "12345"
    #expect(!draft.canSave)
    draft.rawData = "590123412345"
    #expect(draft.canSave, "warnings don't block")

    let zappka = EditorDraft(preset: Presets.zappka)
    zappka.zappkaUserId = "1"
    zappka.zappkaSecret = "xyz"
    #expect(!zappka.canSave)
  }

  @Test func deepLinks() {
    let router = Router()
    let id = UUID()
    router.open(Router.url(for: id))
    #expect(router.checkoutCardID == id)
    router.open(Router.url(for: id, edit: true))
    #expect(router.checkoutCardID == nil)
    if case .existing(let editID) = router.editing { #expect(editID == id) } else { Issue.record("not editing") }
  }
}
