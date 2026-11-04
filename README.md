# Cards

Loyalty-card barcodes as native iOS Home Screen widgets, including Żappka's rotating code.
SwiftUI app + WidgetKit extension, iOS 26, no server of its own.

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
- `docs/publishing.md`: how to ship a build to TestFlight

## Where data lives

- Cards: SwiftData store in the App Group container (`group.io.legiec.cards`), shared with the widget.
- Żappka secrets: the Keychain (shared access group, this device only, readable after first unlock).
  Never in the database, never logged. Tests use made-up secrets.
- Żabka sign-in: "Sign in with Żabka" in the editor is the only network traffic. It talks to
  Google Identity Toolkit and `*.spapp.zabka.pl` the way the official app does (flow from
  [iGerman00/zabka-totp-webapp](https://github.com/iGerman00/zabka-totp-webapp)), keeps only the
  User ID and code secret, and never stores the login tokens.
