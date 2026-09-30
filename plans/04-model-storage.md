# Stage 4: Model + storage

← [03-totp-zappka](03-totp-zappka.md) · [Master](00-master.md) · Next: [05-card-view](05-card-view.md)

## Goal
The card data model, the presets, and storage that the app and the widget can both read. The Żappka secret lives in the Keychain, never in the database.

## Files
```
Shared/Model/Card.swift
Shared/Model/CardContent.swift
Shared/Model/CardLogo.swift
Shared/Model/Presets.swift
Shared/Storage/SharedStore.swift        # ModelContainer factory (App Group)
Shared/Storage/SecretStore.swift        # Keychain wrapper
Shared/Resources/Logos.xcassets         # zappka, biedronka, rossmann, parkrun, empik (vector PDF/SVG where possible, see below)
CardsTests/ModelTests.swift
CardsTests/SecretStoreTests.swift
```
The shared asset catalog must be in both targets (`Shared/` is already in both).

## `Card` (SwiftData `@Model`)
A card is: a name, what the code encodes (a fixed number, or Żappka credentials), the code type, two brand colours and a logo, plus identity and ordering.

| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | `@Attribute(.unique)`. Also used as the widget entity ID. |
| `name` | `String` | Shown in the list and in the widget picker. Defaults to the preset name. |
| `presetID` | `String?` | `"zappka"`, `"biedronka"`, … or nil for custom. Informational: styling is always stored on the card. |
| `symbologyRaw` | `String` | `Symbology.rawValue`, default `pdf417` |
| `contentKind` | `String` | `"raw"` or `"zappka"` |
| `rawData` | `String` | Used when the kind is raw |
| `zappkaUserId` | `String` | Used when the kind is zappka. Not secret. |
| `color1Hex`, `color2Hex` | `String` | `#RRGGBB`, the gradient's start and end |
| `logoKind` | `String` | `"none"`, `"preset"` or `"custom"` |
| `logoPresetName` | `String?` | Asset name |
| `logoImageData` | `Data?` | `@Attribute(.externalStorage)`, PNG, downscaled when picked to max 600 px high |
| `showsCaption` | `Bool` | Human-readable text under 1D codes. Default true. |
| `sortIndex` | `Int` | List order |
| `createdAt`, `updatedAt` | `Date` | |

SwiftData stores primitives most reliably, so there are no enums with associated values in stored properties. Computed wrappers provide the typed API: `symbology: Symbology`, `content: CardContent`, `logo: CardLogo`, `color1: Color`, `color2: Color`.

`CardContent`:
```swift
enum CardContent { case raw(String); case zappka(userId: String) }   // secret fetched from SecretStore by card.id
```

A **value snapshot** `CardSnapshot: Sendable, Hashable` (all fields plus the resolved secret) is what views and the widget render. It is decoupled from the live SwiftData object, which isn't `Sendable` and can't cross into widget timeline entries. `Card.snapshot(secrets:)` builds it.

## `Presets.swift`
Built-in starting points. The colours are the brands' own (listed in the master plan's known facts).

**Logos:** add each brand logo to `Logos.xcassets` as a vector (single-scale PDF or SVG, "Preserve Vector Data") so it's crisp at every widget size. Find official brand assets fresh; don't copy files from the old repos.

| id | name | color1 | color2 | logo | content | symbology |
|---|---|---|---|---|---|---|
| custom | Custom | #ff00ff | #ff0000 | none | raw | pdf417 |
| zappka | Żappka | #01B15B | #00A335 | zappka | zappka | pdf417 |
| biedronka | Biedronka | #9a0100 | #ff0011 | biedronka | raw | pdf417* |
| rossmann | Rossmann | #C20225 | #A2021F | rossmann | raw | pdf417* |
| parkrun | parkrun | #fea301 | #fe7e01 | parkrun | raw | pdf417* |
| empik | Empik | #2A2A2A | #000000 | empik | raw | pdf417* |

\* PDF417 is a placeholder. The real cards may use other symbologies. This is flagged as **open question Q1** in [06-app-editor](06-app-editor.md): the preset's default code type can change later, and the user can always switch it per card.

`Preset.apply(to: Card)` sets the colours, logo, content kind and symbology. It **keeps** existing data, so switching presets doesn't wipe a typed card number. 

## `SharedStore`
```swift
enum SharedStore {
  static let appGroup = "group.io.legiec.cards"
  static func makeContainer(inMemory: Bool = false) throws -> ModelContainer
}
```
- `ModelConfiguration(schema:…, groupContainer: .identifier(appGroup))`, so the app and the widget open the same SQLite file.
- The widget opens the container **read-only in spirit**: it only fetches, never writes.
- `inMemory: true` for tests and SwiftUI previews.
- Add a `VersionedSchema` (`CardsSchemaV1`) and a `SchemaMigrationPlan` now, so later model changes don't lose data.
- After any save in the app: call `WidgetCenter.shared.reloadAllTimelines()`. Wire it up in stage 7, and add a `// TODO(stage 7)` here.

## `SecretStore` (Keychain)
```swift
struct SecretStore: Sendable {
  static let accessGroup: String   // "<TeamPrefix>.io.legiec.cards.shared", read from entitlement/Info.plist key
  func zappkaSecret(for cardID: UUID) throws -> String?
  func setZappkaSecret(_ hex: String?, for cardID: UUID) throws   // nil deletes
}
```
- `kSecClassGenericPassword`, service `io.legiec.cards.zappka`, account `cardID.uuidString`
- `kSecAttrAccessibleAfterFirstUnlock`, so the widget can read it while the phone is locked
- `kSecAttrAccessGroup`: the shared group, so the extension can read it
- no iCloud sync (`kSecAttrSynchronizable = false`)
- Deleting a card deletes its secret.
- The simulator's Keychain works in tests, but access groups need an entitlements-signed host app. Tests run hosted in `Cards` (stage 1 set this up).

## Tests
- Preset apply: colours and logo set, raw data kept
- Round trip through an in-memory container: create, fetch, snapshot
- SecretStore: set, get, overwrite, delete (hosted test, unique test service name, cleaned up after)
- `CardSnapshot` equality drives view identity, so the same data gives an equal snapshot

## Acceptance
- [ ] Model, presets and stores compile into both targets
- [ ] Tests pass
- [ ] Logos render in a throwaway `#Preview`
