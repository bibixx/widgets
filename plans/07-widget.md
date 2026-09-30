# Stage 7: Widget extension

← [06-app-editor](06-app-editor.md) · [Master](00-master.md) · Next: [08-polish-device](08-polish-device.md)

## Goal
Real Home Screen widgets. Each one shows a card chosen via "Edit widget", in small, medium or large. Static cards stay put, and Żappka codes rotate every 30 s without the app being open.

## How WidgetKit works (for a web developer)
The widget isn't a live process. iOS asks your `TimelineProvider` for a **timeline**: an array of `(date, entry)` pairs plus a reload policy. It then renders `entry` → SwiftUI at each date, and archives the result. It's like pre-rendering a list of snapshots with their go-live times. You can't run timers or code between entries. Only special views like `Text(timerInterval:)` animate on their own. There's also a daily refresh budget (roughly 40–70 reloads), but **the entries inside one timeline don't count against that budget**. So Żappka works by handing iOS many pre-computed entries at once.

## Files
```
CardsWidget/CardsWidgetBundle.swift     # @main, contains CardWidget
CardsWidget/CardWidget.swift            # AppIntentConfiguration, families, contentMarginsDisabled
CardsWidget/SelectCardIntent.swift      # WidgetConfigurationIntent { @Parameter card: CardEntity? }
CardsWidget/CardEntity.swift            # AppEntity + EntityQuery reading SharedStore
CardsWidget/Provider.swift              # AppIntentTimelineProvider
CardsWidget/CardWidgetView.swift        # maps WidgetFamily/renderingMode → CardView
CardsWidget/RefreshIntent.swift         # AppIntent used by an interactive Button
Shared/Widget/WidgetReloader.swift      # WidgetCenter wrapper the app calls after saves
CardsTests/ProviderTests.swift
```
`CardEntity` and `SelectCardIntent` must also be compiled into the app target, so iOS can resolve the intent from either process. Put them in `Shared/Widget/` instead, if that's cleaner.

## Configuration: "Edit widget" → pick a card
- `CardEntity: AppEntity`, with `id: UUID`, `name`, and `displayRepresentation` (name + code type, and a logo image if that's easy)
- `CardEntityQuery: EntityQuery`:
  - `entities(for:)` and `suggestedEntities()` fetch from `SharedStore` sorted by `sortIndex`
  - `defaultResult()` returns the first card, so a freshly added widget shows something
- `SelectCardIntent: WidgetConfigurationIntent`, titled "Choose card", with `@Parameter(title: "Card") var card: CardEntity?`
- `CardWidget`:
  - `AppIntentConfiguration(kind: "CardWidget", intent: SelectCardIntent.self, provider: Provider())`
  - `.supportedFamilies([.systemSmall, .systemMedium, .systemLarge])`
  - `.contentMarginsDisabled()`, because the header runs edge to edge (see the stage 5 design)
  - `.configurationDisplayName("Loyalty card")`

## Timeline (`Provider`)
The entry is `CardEntry(date: Date, card: CardSnapshot?, state: .ok | .noCards | .deleted | .needsSecret)`.

- **placeholder:** a Żappka-styled fixture with a redacted code (`.redacted(reason: .placeholder)` look)
- **snapshot** (gallery preview): the real first card, or the fixture if there are no cards
- **timeline(for:in:):**
  1. Resolve the card by `configuration.card?.id`. If it was deleted, return a `.deleted` entry ("Card removed — edit widget") with policy `.never`.
  2. **Raw card:** one entry at `now`, policy `.never`. The app reloads it after edits via `WidgetReloader`.
  3. **Żappka card:**
     - read the secret from `SecretStore`. If it's missing → `.needsSecret` entry.
     - `start = TOTP.window(containing: now).start`, then one entry every 30 s for the next **60 minutes**, i.e. 121 entries
     - each entry carries only the snapshot and the date, and `CardView` computes the code from `entry.date`
     - policy `.atEnd`, so iOS asks for more when they run out
     - make the horizon a single constant and tune it in stage 8 if iOS drops long timelines
  - Keep entries light: the `CardSnapshot` is shared, the logo `Data` is one copy, and the barcode is **not** pre-rendered per entry.

### Honest limits and fallbacks (Żappka)
iOS generally renders timeline entries on schedule for Home Screen widgets, but **doesn't guarantee it** (low power mode, memory pressure). Mitigations:
1. The countdown `Text(timerInterval:)` shows when the displayed code expires. If it reads 0:00 and hasn't changed, the code is stale and you know it at a glance.
2. **Refresh button:** on medium and large, a small `Button(intent: RefreshIntent())` with the ↻ symbol sits in the header, left of the countdown. `RefreshIntent.perform()` calls `WidgetCenter.shared.reloadTimelines(ofKind:)`. This is an interactive widget: the button runs without opening the app.
3. **Tap anywhere else** → `widgetURL(cards://card/<id>)` → the app's fullscreen checkout view with a guaranteed-live code.
Stage 8 verifies all three on a device.

## Rendering
`CardWidgetView`:
- reads `@Environment(\.widgetFamily)` and `@Environment(\.widgetRenderingMode)`, maps them to `CardFamily` and `CardRenderingMode`, and renders `CardView(card:, family:, date: entry.date, renderingMode:)`
- `.containerBackground(.white, for: .widget)`
- the header gradient is drawn inside `CardView`, not as the container background, so it stays full-bleed and matches the editor preview exactly
- state views for `.noCards` ("Open Cards to add a card"), `.deleted` and `.needsSecret`, all tappable into the app

## App ↔ widget sync
- `WidgetReloader.reloadAll()` is called after saving, deleting or reordering a card. It debounces by 0.5 s.
- When the app launches, it reloads once too, in case the widget has cached stale data.

## Tests
- `ProviderTests` (the provider logic sits in a testable function that takes `now`, a store and secrets):
  - raw card → 1 entry, `.never`
  - Żappka → 121 entries aligned to 30 s boundaries, the first entry ≤ now, `.atEnd`
  - Żappka with no secret → `.needsSecret`
  - unknown ID → `.deleted`
  - no cards → `.noCards`
- A Vision decode of the `ImageRenderer` output of `CardWidgetView` at medium size for a Żappka entry gives the payload for that entry's date

## Acceptance
- [ ] In the simulator: add small, medium and large widgets, pick different cards, and each shows the right card
- [ ] Editing a card in the app updates its widget within a few seconds
- [ ] The Żappka widget's code changes at the 30 s boundaries while you watch (simulator first, then a device in stage 8)
- [ ] The refresh button works, and tapping the widget opens that card's fullscreen view
