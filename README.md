# Cards

Loyalty-card barcodes as native iOS Home Screen widgets, including Żappka's rotating code.
SwiftUI app + WidgetKit extension, iOS 26, no server.

## Build

```sh
brew install xcodegen          # once
xcodegen generate              # after pulling or adding files
open Cards.xcodeproj
# or headless:
xcodebuild -scheme Cards -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build test
```

`project.yml` is the source of truth; `Cards.xcodeproj` is generated and not committed.
Signing: set `DEVELOPMENT_TEAM` in the environment before `xcodegen generate` (never committed).

Debug launch arguments: `-seed-samples` fills an empty store with made-up cards,
`-open cards://card/<id>` routes a deep link.

## Layout

- `Cards/` app: card list, editor with a live preview of every option
- `CardsWidget/` widget extension: card picker, timelines
- `Shared/` compiled into both: model, storage, barcode engine (zxing-cpp), TOTP/Żappka, `CardView`
- `docs/presets.md`: how to add a store preset

## Where data lives

- Cards: SwiftData store in the App Group container (`group.io.legiec.cards`), shared with the widget.
- Żappka secrets: the Keychain (shared access group, this device only, readable after first unlock).
  Never in the database, never logged. Tests use made-up secrets.
