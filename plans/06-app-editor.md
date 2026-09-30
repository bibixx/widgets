# Stage 6: App: card list, editor with live preview, checkout view

← [05-card-view](05-card-view.md) · [Master](00-master.md) · Next: [07-widget](07-widget.md)

## Goal
The app you actually use: a list of cards, an editor where **every option is reflected live in a preview while you edit**, and a fullscreen checkout view. There's nothing to build or export: saving updates the widgets.

## Files
```
Cards/CardsApp.swift                 # ModelContainer from SharedStore, onOpenURL routing
Cards/Router.swift                   # @Observable navigation state (path, sheet, fullscreen card)
Cards/List/CardListView.swift
Cards/List/CardRow.swift
Cards/Editor/CardEditorView.swift
Cards/Editor/EditorDraft.swift       # editable copy of a card (+ secret) — commit on Save
Cards/Editor/LivePreviewPanel.swift
Cards/Editor/Sections/*.swift        # PresetSection, ContentSection, CodeTypeSection, StyleSection, LogoSection
Cards/Checkout/CardFullscreenView.swift
CardsTests/EditorDraftTests.swift
```

## Navigation
- `NavigationStack` rooted at `CardListView`
- Tapping a row opens the **fullscreen checkout view**, since that's the common case at the till. Swipe or context menu → Edit.
- `+` → pick a preset (grid of preset tiles with logos) → editor pre-filled from that preset
- Deep link `cards://card/<uuid>` (from the widget) → fullscreen for that card
- Deep link `cards://card/<uuid>/edit` → editor

## Card list
- Rows show a mini `CardView(family: .small)` thumbnail, the name, and the code type
- Reorder (`onMove` → `sortIndex`), swipe to delete (with confirmation, and the Keychain secret is deleted too)
- Empty state: "Add your first card" with preset tiles
- Toolbar: `+`

## Editor: draft model
`EditorDraft` is an `@Observable` value copy of the card's fields plus the Żappka secret string.
- The editor binds to the draft, not to the live `Card`. **Cancel** throws the draft away, and **Save** writes the card and the Keychain secret, then reloads the widgets.
- It's like react-hook-form's local form state before submit.
- `draft.snapshot(at:)` produces a `CardSnapshot` for the preview. This is the same type the widget renders, so **what you preview is exactly what the widget draws**.
- `draft.issues` holds the validation results from stages 2 and 3, shown inline under each field. Save stays enabled when there are only warnings, and is disabled when there are errors.

## Editor: form sections
1. **Preset:** a picker with the logo next to each name. Choosing one applies colours, logo, content kind and symbology, and **keeps** the typed data (see stage 4).
2. **Name:** a text field (defaults to the preset name).
3. **Content:**
   - Segmented control: **Card number** (raw) vs **Żappka (rotating)**.
   - Raw: text field with the keyboard type from the symbology, a scan button (`DataScannerViewController` via VisionKit) to read an existing physical card, and inline validation with the auto-fix hint ("Check digit added").
   - Żappka:
     - `User ID` field and `Secret` (`SecureField` with a reveal toggle)
     - a **Paste** button next to each field (user-initiated `UIPasteboard` read, so iOS shows no prompt). The secret paste normalises whitespace/case.
     - a **Test** row showing the current 6-digit code and the seconds left, ticking live
     - a footnote: "Stored in the Keychain on this device only."
4. **Code type:** a picker over `Symbology.allCases`, grouped as 2D / Stacked / Linear. Żappka locks it to PDF417, with a footnote explaining why. "Show number under code" toggle, for linear codes only.
5. **Colours:** two `ColorPicker`s, "From" and "To", plus a "Swap" button and "Reset to preset".
6. **Logo:**
   - options: None / Preset (pick from bundled logos) / Custom (`PhotosPicker` or the Files picker)
   - Custom images are downscaled to 600 px high and stored as PNG
   - a "Remove background" toggle (optional, only if `VNGenerateForegroundInstanceMaskRequest` makes it trivial; otherwise skip)

## Live preview: every option, live
`LivePreviewPanel` pins to the top of the editor. On iPad or landscape it moves to a side column.
- **What updates live:** every field in the draft. The panel observes the draft, so typing, colour dragging, preset switching, logo changes, code type changes and credential edits all redraw immediately. There is no "Apply" step.
- **Size switcher:** segmented **Small / Medium / Large / Fullscreen**, plus an **"All"** mode showing all three widget sizes stacked, the way they'd sit on a Home Screen.
- **Rendering mode switcher:** **Full colour / Tinted / Clear**. This passes `renderingMode` to `CardView` (stage 5), so you can check the tinted Home Screen look while editing.
- **Background toggle:** light wallpaper / dark wallpaper / custom photo behind the preview, to judge the outline and tint.
- **Time:** the preview is wrapped in `TimelineView(.periodic(from: .now, by: 1))`, so Żappka codes and countdowns tick in real time in the editor, exactly as on the widget.
- **Scan check:** a small badge under the preview. It runs the Vision decoder from stage 2 on an `ImageRenderer` render of the current preview (debounced 300 ms) and shows ✅ "Scannable" or ⚠️ "Hard to scan at this size". It catches cases like a long 1D code squeezed into a small widget.
- **Real widget sizes:**
  - `CardLayout` needs the real point sizes of each widget family on this device
  - use a small table keyed by screen size, measured from simulator and device Home Screen screenshots (stage 8)
  - fallback: iPhone 13 Pro values (158×158, 338×158, 338×354)
  - so the preview is pixel-true, not merely proportional
- The preview has a zero-state for an empty draft: the placeholder code with a "Sample" badge.

## Checkout view (`CardFullscreenView`)
- A white screen: the card's gradient header with the logo, then the code as large as possible (landscape rotates the code for 1D and PDF417), then the number caption.
- On appear, brightness goes to 100% and is restored on disappear. The idle timer is disabled while it's visible.
- Żappka: a live code via `TimelineView(.periodic(by: 1))`, a big countdown, and a haptic tick when the code rotates.
- Swipe down to dismiss. Also horizontal paging between cards (a `TabView` page style), for quickly switching at the till.

## Open questions (ask the user when this stage starts)
- **Q1:** which symbology does each real card use? The reference widgets for Rossmann, Empik and the Żappka barcode card look like **Code128** (start pattern matches Code128 Start C); confirm, and ask about Biedronka and parkrun. The answer sets each preset's default symbology.
- **Q2:** app display name (placeholder "Cards").

## Tests
- `EditorDraftTests`:
  - loading a card → draft → save round-trips every field
  - Cancel changes nothing
  - preset switching keeps data
  - Żappka mode forces PDF417
  - validation errors block Save
- UI smoke (optional): XCUITest creates a raw EAN-13 card and checks that the preview shows "Scannable".

## Acceptance
- [ ] Changing any field updates the preview within one frame, and the Żappka code ticks live in the editor
- [ ] Every size and rendering mode is previewable from the editor
- [ ] Saving or deleting reloads the widgets (after stage 7)
- [ ] The checkout view maxes the brightness and restores it
