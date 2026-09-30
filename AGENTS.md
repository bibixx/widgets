# AGENTS.md

This file provides guidance to coding agents working with code in this repository.

Cards: loyalty-card barcodes as iOS Home Screen widgets, including Żappka's rotating (TOTP) code.
SwiftUI app + WidgetKit extension, iOS 26, Swift 6 with complete strict concurrency, no server.

## Commands

`project.yml` (XcodeGen) is the source of truth. `Cards.xcodeproj` is generated and gitignored, so
regenerate it after adding, moving or deleting files:

```sh
xcodegen generate
xcodebuild -scheme Cards -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -scheme Cards -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
# one suite / one test (Swift Testing):
xcodebuild ... test -only-testing:CardsTests/CardViewRenderTests
xcodebuild ... test -only-testing:CardsTests/CardViewRenderTests/mediumZappkaPDF417Decodes
```

Signing: `DEVELOPMENT_TEAM` comes from the environment at `xcodegen generate` time; never commit it.

Debug launch arguments: `-seed-samples` fills an empty store with the made-up cards from
`CardPreviewFixtures`; `-open cards://card/<id>` routes a deep link without the system prompt.

Tests use Swift Testing (`import Testing`, `@Test`, `#expect`), not XCTest. `CardViewRenderTests`
can dump rendered PNGs to `/tmp/cards-render/` for eyeballing.

## Architecture

Three targets: `Cards` (app), `CardsWidget` (extension), `CardsTests`. `Shared/` is compiled
into both the app and the widget (not a framework), so anything there must work in the extension.

**Data flow.** `Card` (SwiftData `@Model`, in `CardsSchemaV1`) stores everything as primitives
(`symbologyRaw`, `contentKind`, `logoKind`, ...) with typed computed wrappers. Schema changes need
a new `VersionedSchema` plus a stage in `CardsMigrationPlan`. Views and widget entries never touch
`Card` directly: they render a `CardSnapshot` (Sendable value copy + resolved Żappka secret) via
`card.snapshot()`.

**Storage.** `SharedStore` opens one SQLite file in the App Group container
(`group.io.legiec.cards`); the app writes, the widget only reads. Żappka secrets live only in the
Keychain (`SecretStore`, shared access group, keyed by card id), never in SwiftData and never
logged. Tests and fixtures use made-up secrets and numbers.

**Rendering.** `CardView` is the single visual used by the widget, the card list and the editor's
live preview. Rules that span files:
- `CardView` takes an explicit `date`; never call `Date()` inside rendering code (timeline
  entries and `TimelineView` drive it).
- Each card has two code types: `symbology` for the horizontal (medium) widget and
  `squareSymbology` for small/large. `CardSnapshot.rendered(for:)` picks one, and forces
  Żappka's fixed types (`Zappka.symbology` / `.squareSymbology`) regardless of what's stored.
- `CardCode.resolve` turns a snapshot + date into either a code (text/caption) or a `problem`
  message shown in place of the barcode.
- `CardLayout` is a port of an old web renderer that worked in CSS px at 3×: sizes are written
  as `px / 3` points with the px value in a comment. Keep that convention.
- Barcodes: `BarcodeRenderer` (zxing-cpp) returns a 1-pixel-per-module `CGImage`; `CodeRaster`
  draws it pixel-exact. Only nearest-neighbour scaling; CG interpolated scaling breaks linear
  codes. Nothing outside `Shared/Barcode` imports `ZXingCpp`. `BarcodeValidation` normalizes and
  validates input per symbology.

**Widget.** `CardWidget` uses `AppIntentConfiguration` with `SelectCardIntent` / `CardEntity`.
Timeline logic is pure and testable in `CardTimeline.entries` (static cards: one entry, policy
`.never`; Żappka: one entry per 30 s window for an hour, policy `.atEnd`). The app calls
`WidgetReloader.reloadAll()` (debounced) after any save/delete/reorder. Tapping a widget opens
`cards://card/<uuid>`, which `Router` turns into the editor.

**Editor.** `EditorDraft` is an `@Observable` copy of a card plus its secret; Cancel discards it,
Save writes both the card and the Keychain secret. Switching content kind or preset must keep what
the user already typed (card number, Żappka User ID). `CodeImporter` / `EditorDropCatcher` read a
code from a photo or dropped image (`BarcodeDecoder`) to fill the draft.
Drops can't be handled inside the sheet: the Form's collection view and SwiftUI's hosting views
claim drags and refuse images, so `.dropDestination` or per-view drop interactions only work in
patches. `EditorDropCatcher` instead shows a transparent window above everything while the editor
is open. It passes every real touch through and answers only hit tests that come with a
`UIDragEvent`. Taps arrive as `UITouchesEvent` with no touches attached yet, so don't use
"no touches" to detect drags.

## Presets and logos

Store presets are code in `Shared/Model/Presets.swift`; follow `docs/presets.md` when adding one.
Key constraints:
- `Preset.id` is persisted in `Card.presetID`: never rename or reuse one.
- Logo PNGs in `Shared/Resources/Logos.xcassets` must stay about 240 px tall and well under 1 MP,
  or WidgetKit silently shows the placeholder (`LogoTests` enforces this).
- Colours are `#RRGGBB`.
- New sample cards go in `CardPreviewFixtures.all` and the `everyFamilyDecodes` test arguments.

## Conventions

- 2-space indentation.
- Horizontal `ScrollView`s get `.scrollEdgeFades()` (defined in `Cards/Editor/ScrollEdgeFades.swift`).
- Vision's barcode detector finds nothing in the simulator, so tests decode with zxing
  (`TestDecoder.decodeAll`) and only add Vision on device.
