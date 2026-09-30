# Stage 5: CardView (the visual)

← [04-model-storage](04-model-storage.md) · [Master](00-master.md) · Next: [06-app-editor](06-app-editor.md)

## Goal
One SwiftUI view that draws a card, used everywhere: in the widget, in the editor's live preview, and (scaled up) in the fullscreen checkout view. There's a single source of truth for the look.

## Files
```
Shared/Views/CardView.swift
Shared/Views/CardLayout.swift          # size/family → metrics (pure, testable)
Shared/Views/BarcodeImageView.swift    # renders BarcodeRenderer output crisply, handles errors
Shared/Views/ZappkaCountdown.swift     # header countdown
Shared/Views/CardPreviewFixtures.swift # sample snapshots for #Preview (Żappka with test secret, each preset)
```

## API
```swift
struct CardView: View {
  let card: CardSnapshot
  let family: CardFamily          // .small, .medium, .large, .fullscreen
  let date: Date                  // the moment to render (timeline entry date / TimelineView tick)
  var renderingMode: CardRenderingMode = .fullColor   // .fullColor, .accented, .vibrant
  var showsCountdown: Bool = true
}
```
- `CardFamily` is our own enum, mapped from `WidgetFamily` in the widget. That way the editor can render every size without WidgetKit context.
- `renderingMode` is passed in explicitly, not read from `@Environment(\.widgetRenderingMode)`. The widget passes the environment value, and the editor passes whichever mode the user is previewing. This is what lets the editor show every option.
- `date` is passed in, never `Date()` inside the view. That keeps it deterministic for timelines, previews and tests.

## Widget design: the user's widgy design, reproduced exactly
The **widgets** must look like the cards the user designed in widgy (the app's own UI is native and doesn't copy widgy). References, all medium size, 2961×1395 px: [Żappka](reference/widget-zappka.png), [Rossmann](reference/widget-rossmann.png), [Empik](reference/widget-empik.png). The numbers below were measured from those images by pixel scan, and all three share identical geometry.

**Medium (the reference), as fractions of the widget's width W and height H:**

| Element | Spec |
|---|---|
| Background | plain white, edge to edge (`.contentMarginsDisabled()`, `containerBackground(.white)`) |
| Header | full width, top **24.1% of H**. **Vertical** gradient, `color1` at the top → `color2` at the bottom (e.g. Żappka `#01B15B`→`#00A335`, Empik `#2A2A2A`→`#000000`). No outline or divider. |
| Logo | white artwork, leading edge at **6.5% of W** (lined up with the code's left edge), vertically centred in the header, fitted inside a box **≈57% of the header height** tall and up to ≈36% of W wide, `.scaledToFit`, leading-aligned |
| Code area | x from **6.5% to 93.5% of W** (87% wide), y from **34.4% to 89.6% of H** (55.2% tall), i.e. centred in the white body with equal ≈10.4% gaps above and below |
| Code corners | the whole code is clipped to a rounded rect with a tiny radius, **≈0.4% of W** (about 1.5 pt): the outer bars get softly rounded corners |
| Caption (linear codes) | the number in a **monospaced** font (SF Mono look, slashed zero), black, wide letter-spacing, **cap height ≈4.6% of H**, baseline on the code's bottom edge, centred horizontally |
| Caption notch | a white rectangle behind the caption cuts the bars: it starts **83.0% of H** (≈1.9% of H above the digits) and runs to the code's bottom; it's as wide as the text plus **≈3.9% of W** padding on each side. Bars on either side of the notch keep full height. |
| Countdown (Żappka only) | in the header, trailing edge at 93.5% of W, vertically centred: `.system(.body, design: .monospaced).weight(.semibold)`, white at 66% opacity (the old HH:mm:ss clock's spot and style) |

The caption and notch recreate the look from the references; they are drawn by `CardView`, not by the barcode library, so no caption text is ever baked into the code image.

**Small and large** have no widgy reference, so derive them from the medium spec: keep the header, logo, insets and caption at the **same absolute point sizes** as a medium widget on the same device (so widgets stacked on a Home Screen line up), and give the code the remaining area. Review screenshots of both with the user before stage 6.

**Fullscreen (app checkout view):** same header + code composition, scaled to the screen, with the code as large as possible.

All of these numbers live in `CardLayout` as a pure function `metrics(for family:, size: CGSize, symbology:) -> Metrics`, so they're unit-testable and tweakable in one place.

Per-symbology rules (inside the code area):
- **Linear (the reference cards look like Code128):** bars stretch across the full code area, with the caption notch as specified. Hide the caption and notch when `card.showsCaption == false`.
- **Stacked (PDF417, Żappka):** keep the native aspect ratio, fitted and centred in the code area. No caption. This is the most important case to get scannable.
- **Square (QR/Aztec/DataMatrix):** 1:1, centred in the code area (height-limited in medium).
- Code images always use `.interpolation(.none)` and `.antialiased(false)`, keep at least a 4-module white quiet zone, and are black on white.

## Content resolution (inside CardView)
- `.raw(text)`: validate (stage 2). If the text is empty, use `symbology.placeholder` drawn at 30% opacity with a "Sample" badge (editor only; `card.isPreview`). If it's invalid, show an error tile with an icon and a short message. **Never crash, and never show a blank white box.**
- `.zappka`:
  - `Zappka.payload(for: creds, at: date)`, rendered as PDF417
  - if the secret is missing or invalid: an error tile that says "Add your Żappka secret"
  - the countdown shows the time left until `TOTP.window(containing: date).end`, using `Text(timerInterval: date...end, countsDown: true)`. It ticks live inside widgets without timeline reloads.
  - The countdown is the freshness cue: when it reads 0:00 and the code didn't change, the code is stale.

## Rendering modes
Widgets on iOS 26 can be shown **full colour**, **accented/tinted** (Home Screen tint) or **clear/vibrant**.
- **Header:** mark the gradient and logo `.widgetAccentable()`, so they take the tint.
- **Code:** it must stay pure black on white in every mode, or scanners fail.
  - Apply `.widgetAccentedRenderingMode(.fullColor)` to the code image, so the system doesn't desaturate or tint it.
  - Keep the white code plate opaque.
  - Verify this in stage 8 on a real tinted Home Screen. If it's still unscannable, the tap-to-fullscreen fallback covers it.
- For preview parity, `CardView` takes `renderingMode` and emulates the look in the editor: the accented mode renders the header in a flat tint colour.

## Performance
- Barcode rendering goes through the `BarcodeRenderer` cache.
- Custom logo `Data` → `UIImage` is decoded once per snapshot (use a small cache keyed by the data hash).
- Target: `CardView` body evaluation under 5 ms for Żappka on device (measured in stage 8).

## Previews and tests
- `#Preview`s: every preset × {small, medium, large, fullscreen} × {fullColor, accented}, with fixtures from `CardPreviewFixtures`. The Żappka fixture uses a fixed test secret and a fixed date.
- `CardLayoutTests`: metrics for each family and symbology, sanity checks (code area inside the card, non-negative sizes).
- `CardLayoutTests` also asserts the medium metrics equal the measured reference fractions.
- Snapshot test (optional, no dependency): render with `ImageRenderer` at a fixed size and run the Vision decoder from stage 2 on the output. Check that **the PDF417 in a medium card is still decodable**. This is the most valuable test in the stage.

## Acceptance
- [ ] A medium Rossmann/Empik/Żappka preview overlaid on its reference image (`reference/*.png`, scaled to the same size) matches: header height, logo position, code box and caption notch within ~1% of W/H
- [ ] Small and large layouts reviewed with the user
- [ ] A PDF417 rendered through `CardView` at medium size decodes with Vision
- [ ] Error and empty states render nicely at every size
