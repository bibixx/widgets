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
  var squareSymbology: Symbology
  var contentKind: CardContent.Kind
  var rawData: String
  var zappkaUserId: String
  var zappkaSecret: String
  /// National digits of the number used to sign in; empty when the credentials came from elsewhere.
  var zappkaPhone: String
  var color1Hex: String
  var color2Hex: String
  var logo: CardLogo
  var showsCaption: Bool
  /// What tapping the widget opens, as typed; empty opens the editor.
  var tapURL: String

  init(preset: Preset) {
    cardID = UUID()
    isNew = true
    name = preset.id == Presets.custom.id ? "" : preset.name
    presetID = preset.id
    symbology = preset.symbology
    squareSymbology = preset.squareSymbology
    contentKind = preset.contentKind
    rawData = ""
    zappkaUserId = ""
    zappkaSecret = ""
    zappkaPhone = ""
    color1Hex = preset.color1Hex
    color2Hex = preset.color2Hex
    logo = preset.logo
    showsCaption = true
    tapURL = preset.appURL ?? ""
  }

  init(card: Card, secret: String?) {
    cardID = card.id
    isNew = false
    name = card.name
    presetID = card.presetID
    symbology = card.symbology
    squareSymbology = card.squareSymbology
    contentKind = card.content.kind
    rawData = card.rawData
    zappkaUserId = card.zappkaUserId
    zappkaSecret = secret ?? ""
    zappkaPhone = card.zappkaPhone ?? ""
    color1Hex = card.color1Hex
    color2Hex = card.color2Hex
    logo = card.logo
    showsCaption = card.showsCaption
    tapURL = card.tapURL ?? ""
  }

  var preset: Preset? { Presets.preset(id: presetID) }

  /// Applies styling, content kind and code type; keeps typed data. A name that still
  /// equals the old preset's name follows the new preset.
  func apply(_ preset: Preset) {
    if name.isEmpty || name == self.preset?.name { name = preset.id == Presets.custom.id ? "" : preset.name }
    if tapURL.isEmpty || tapURL == self.preset?.appURL { tapURL = preset.appURL ?? "" }
    presetID = preset.id
    color1Hex = preset.color1Hex
    color2Hex = preset.color2Hex
    logo = preset.logo
    symbology = preset.symbology
    squareSymbology = preset.squareSymbology
    contentKind = preset.contentKind
  }

  /// Fills the card number from a scanned or imported barcode and adopts its code type:
  /// 2D codes for the square widgets, the rest for the horizontal one.
  func importCode(_ code: BarcodeDecoder.Detected) {
    if let symbology = code.symbology {
      if symbology.kind == .twoD { squareSymbology = symbology } else { self.symbology = symbology }
    }
    rawData = code.text
  }

  /// Fills the Żappka fields from a sign-in, replacing what was there.
  func apply(_ credentials: ZappkaCredentials, phone: String? = nil) {
    zappkaUserId = credentials.userId
    zappkaSecret = credentials.secretHex
    zappkaPhone = phone ?? ""
  }

  /// Forgets the Żappka credentials; Save then removes the Keychain secret.
  func signOutOfZappka() {
    zappkaUserId = ""
    zappkaSecret = ""
    zappkaPhone = ""
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
    return trimmed.isEmpty ? (preset?.name ?? String(localized: "Card")) : trimmed
  }

  /// Exactly what the widget will draw (plus the "Sample" look for an empty number).
  func snapshot() -> CardSnapshot {
    CardSnapshot(
      id: cardID, name: displayName, presetID: presetID,
      symbology: symbology, squareSymbology: squareSymbology,
      content: content, zappkaSecret: contentKind == .zappka ? credentials.secretHex : nil,
      color1Hex: color1Hex, color2Hex: color2Hex, logo: logo, showsCaption: showsCaption, isPreview: true)
  }

  // MARK: Validation

  /// The number must suit both code types; the first error wins, else the horizontal result.
  var rawValidation: ValidationResult {
    let horizontal = BarcodeValidation.validate(rawData, for: symbology)
    let square = BarcodeValidation.validate(rawData, for: squareSymbology)
    return square.isError && !horizontal.isError ? square : horizontal
  }
  var credentialIssues: [ZappkaCredentials.Issue] { credentials.validate() }

  var colorIssues: [String] {
    [color1Hex, color2Hex].contains { Color.rgb(hex: $0) == nil } ? [String(localized: "Colours must be #RRGGBB")] : []
  }

  var tapLink: TapLink.Parsed { TapLink.parse(tapURL) }

  var hasErrors: Bool {
    if !colorIssues.isEmpty || tapLink == .invalid { return true }
    switch contentKind {
    case .raw: return rawValidation.isError
    case .zappka: return credentialIssues.contains(where: \.isError)
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
    card.squareSymbology = contentKind == .zappka ? Zappka.squareSymbology : squareSymbology
    card.content = content
    // Keep the other kind's field too, so switching kinds later doesn't lose it.
    card.rawData = BarcodeValidation.normalized(rawData, for: symbology)
    card.zappkaUserId = zappkaUserId.trimmingCharacters(in: .whitespacesAndNewlines)
    card.zappkaPhone = zappkaPhone.isEmpty ? nil : zappkaPhone
    card.color1Hex = color1Hex
    card.color2Hex = color2Hex
    card.logo = logo
    card.showsCaption = showsCaption
    if case .url(let url) = tapLink { card.tapURL = url.absoluteString } else { card.tapURL = nil }
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
