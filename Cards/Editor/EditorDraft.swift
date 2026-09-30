import Foundation
import SwiftData
import SwiftUI

/// An editable copy of a card plus its Żappka secret. The editor binds to this; Cancel
/// throws it away and Save writes the card and the Keychain secret.
@MainActor
@Observable
final class EditorDraft {
  let cardID: UUID
  let isNew: Bool
  var name: String
  var presetID: String?
  var symbology: Symbology
  var contentKind: CardContent.Kind
  var rawData: String
  var zappkaUserId: String
  var zappkaSecret: String
  var color1Hex: String
  var color2Hex: String
  var logo: CardLogo
  var showsCaption: Bool

  init(preset: Preset) {
    cardID = UUID()
    isNew = true
    name = preset.id == Presets.custom.id ? "" : preset.name
    presetID = preset.id
    symbology = preset.symbology
    contentKind = preset.contentKind
    rawData = ""
    zappkaUserId = ""
    zappkaSecret = ""
    color1Hex = preset.color1Hex
    color2Hex = preset.color2Hex
    logo = preset.logo
    showsCaption = true
  }

  init(card: Card, secret: String?) {
    cardID = card.id
    isNew = false
    name = card.name
    presetID = card.presetID
    symbology = card.symbology
    contentKind = card.content.kind
    rawData = card.rawData
    zappkaUserId = card.zappkaUserId
    zappkaSecret = secret ?? ""
    color1Hex = card.color1Hex
    color2Hex = card.color2Hex
    logo = card.logo
    showsCaption = card.showsCaption
  }

  var preset: Preset? { Presets.preset(id: presetID) }

  /// Applies styling, content kind and code type; keeps typed data. A name that still
  /// equals the old preset's name follows the new preset.
  func apply(_ preset: Preset) {
    if name.isEmpty || name == self.preset?.name { name = preset.id == Presets.custom.id ? "" : preset.name }
    presetID = preset.id
    color1Hex = preset.color1Hex
    color2Hex = preset.color2Hex
    logo = preset.logo
    symbology = preset.symbology
    contentKind = preset.contentKind
  }

  func setContentKind(_ kind: CardContent.Kind) {
    contentKind = kind
    if kind == .zappka { symbology = Zappka.symbology }
  }

  func resetColorsToPreset() {
    guard let preset else { return }
    color1Hex = preset.color1Hex
    color2Hex = preset.color2Hex
  }

  func swapColors() { swap(&color1Hex, &color2Hex) }

  var content: CardContent {
    switch contentKind {
    case .raw: .raw(rawData)
    case .zappka: .zappka(userId: zappkaUserId.trimmingCharacters(in: .whitespacesAndNewlines))
    }
  }

  var credentials: ZappkaCredentials { ZappkaCredentials(userId: zappkaUserId, secretHex: zappkaSecret) }

  var displayName: String {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? (preset?.name ?? "Card") : trimmed
  }

  /// Exactly what the widget will draw (plus the "Sample" look for an empty number).
  func snapshot() -> CardSnapshot {
    CardSnapshot(
      id: cardID, name: displayName, presetID: presetID,
      symbology: contentKind == .zappka ? Zappka.symbology : symbology,
      content: content, zappkaSecret: contentKind == .zappka ? credentials.secretHex : nil,
      color1Hex: color1Hex, color2Hex: color2Hex, logo: logo, showsCaption: showsCaption, isPreview: true)
  }

  // MARK: Validation

  var rawValidation: ValidationResult { BarcodeValidation.validate(rawData, for: symbology) }
  var credentialIssues: [ZappkaCredentials.Issue] { credentials.validate() }

  var colorIssues: [String] {
    [color1Hex, color2Hex].contains { Color.rgb(hex: $0) == nil } ? ["Colours must be #RRGGBB"] : []
  }

  var hasErrors: Bool {
    switch contentKind {
    case .raw: rawValidation.isError || !colorIssues.isEmpty
    case .zappka: credentialIssues.contains(where: \.isError) || !colorIssues.isEmpty
    }
  }

  var canSave: Bool { !hasErrors }

  // MARK: Save

  /// Writes the card (and its secret) and reloads widgets. Returns the saved card.
  @discardableResult
  func save(in context: ModelContext, secrets: SecretStore = SecretStore()) throws -> Card {
    let card: Card
    if let existing = try SharedStore.fetchCard(id: cardID, in: context) {
      card = existing
    } else {
      let count = (try? context.fetchCount(FetchDescriptor<Card>())) ?? 0
      card = Card(id: cardID, sortIndex: count)
      context.insert(card)
    }
    card.name = displayName
    card.presetID = presetID
    card.symbology = contentKind == .zappka ? Zappka.symbology : symbology
    card.content = content
    // Keep the other kind's field too, so switching kinds later doesn't lose it.
    card.rawData = BarcodeValidation.normalized(rawData, for: symbology)
    card.zappkaUserId = zappkaUserId.trimmingCharacters(in: .whitespacesAndNewlines)
    card.color1Hex = color1Hex
    card.color2Hex = color2Hex
    card.logo = logo
    card.showsCaption = showsCaption
    card.updatedAt = .now
    try context.save()

    try secrets.setZappkaSecret(contentKind == .zappka ? credentials.secretHex : nil, for: cardID)
    WidgetReloader.reloadAll()
    return card
  }
}

extension Card {
  @MainActor
  /// Deletes the card and its Keychain secret.
  static func delete(_ card: Card, in context: ModelContext, secrets: SecretStore = SecretStore()) throws {
    try? secrets.setZappkaSecret(nil, for: card.id)
    context.delete(card)
    try context.save()
    WidgetReloader.reloadAll()
  }
}
