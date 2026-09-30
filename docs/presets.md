# Adding a preset

A preset is a store template: Żappka, Biedronka, Rossmann, parkrun, Empik, and Custom.
Picking one in the editor sets the card's colours, logo, content kind and both code types.
It keeps whatever the user already typed (card number, Żappka User ID).

Presets live in code: `Shared/Model/Presets.swift`. No server, no migration.

## What a preset holds

```swift
struct Preset {
  let id: String                  // persisted in Card.presetID: never rename or reuse
  let name: String                // shown in the picker; also the default card name
  let color1Hex: String           // header gradient, top    (#RRGGBB)
  let color2Hex: String           // header gradient, bottom (#RRGGBB)
  let logoName: String?           // asset in Logos.xcassets, nil = no logo
  let contentKind: CardContent.Kind  // .raw (card number) or .zappka (rotating code)
  let symbology: Symbology        // code on the horizontal (medium) widget
  var squareSymbology = .qr       // code on the square (small, large) widgets
  var appURL: String? = nil       // widget tap link: a universal link the store's app claims
}
```

Only Żappka uses `.zappka`. Its code types are fixed (`Zappka.symbology` /
`Zappka.squareSymbology`) and enforced in `CardSnapshot.rendered(for:)`, whatever the card stores.

## Steps

### 1. Logo asset

Add `Shared/Resources/Logos.xcassets/<id>.imageset/` holding one PNG and this `Contents.json`:

```json
{
  "images" : [ { "filename" : "<id>.png", "idiom" : "universal" } ],
  "info" : { "author" : "xcode", "version" : 1 },
  "properties" : { "template-rendering-intent" : "original" }
}
```

The logo sits on the header gradient. Use white or light artwork on a transparent background.

**Keep it small: about 240 px tall, and well under 1 megapixel.** WidgetKit refuses to archive a
widget holding a bigger image and shows the placeholder instead (a sample Żappka card; tapping it
opens "Card not found"). The only trace is a log line:
`Widget archival failed due to image being too large`.

```sh
sips --resampleHeight 240 Shared/Resources/Logos.xcassets/<id>.imageset/<id>.png
sips -g pixelWidth -g pixelHeight Shared/Resources/Logos.xcassets/<id>.imageset/<id>.png
```

`LogoTests` fails for any preset logo over the limit.

### App link (optional)

Find a universal link the store's app claims: fetch
`https://app-site-association.cdn-apple.com/a/v1/<domain>` for its domains (try `www.`, link
subdomains and `<brand>.onelink.me` / `<brand>.app.link`) and pick a path listed under
`applinks`. Test it on a device with the editor's "Widget tap" Try button. Custom schemes
(`brand://`) work too but fail silently when wrong.

### 2. Define the preset

In `Presets`, add a `static let`. Pick the code type from the store's real card, and say where it
came from in the comment above the list:

```swift
// Lidl Plus: QR in the app, Code 128 on the plastic card (checked against a real card).
static let lidl = Preset(
  id: "lidl", name: "Lidl Plus", color1Hex: "#0050AA", color2Hex: "#003F87",
  logoName: "lidl", contentKind: .raw, symbology: .code128)
```

Leave out `squareSymbology` unless QR is wrong for that store's scanners.

### 3. Register it

Add it to `Presets.all`. That order is the order of the editor's preset strip and the "Add card"
grid. Keep `custom` last.

```swift
static let all: [Preset] = [zappka, biedronka, rossmann, parkrun, empik, lidl, custom]
```

The logo picker gets it automatically (`Presets.logoNames`).

### 4. Tune the logo height (optional)

Logos default to `CardLayout.Style.logoHeight` (64 px at 3×, i.e. 21.3 pt on a medium widget).
If the logo looks too big or too small, add it to `presetLogoHeights` in
`Shared/Views/CardLayout.swift`. Values are pixels ÷ 3:

```swift
static let presetLogoHeights: [String: CGFloat] = [..., "lidl": 52.0 / 3]
```

### 5. Add a sample card (optional)

In `Shared/Views/CardPreviewFixtures.swift`, add a sample with a **made-up** number and put it in
`all`. The sample then shows in SwiftUI previews and in `-seed-samples`:

```swift
static let lidl = card(Presets.lidl, content: .raw("0123456789012"), symbology: .code128)
```

Then add `"lidl"` to the `everyFamilyDecodes` arguments in `CardsTests/CardViewRenderTests.swift`.
That test renders the card on small, medium and large, and decodes each one.

## Check it

```sh
xcodegen generate
xcodebuild -scheme Cards -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Then in the simulator:
- Launch with `-seed-samples`. Create a card from the new preset, and switch presets back and
  forth: the number must survive.
- Add a small, a medium and a large widget. The logo is crisp and sized like the others, and the
  code isn't the placeholder.
- Scan the medium code with a phone, or better, at the till.

## Rules

- `id` is stored on every card made from the preset. Renaming it orphans those cards (they keep
  their look but lose "Reset to preset").
- Colours are `#RRGGBB`. The editor rejects anything else.
- Logos are the stores' trademarks. This app is for personal use only.
