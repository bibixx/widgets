# Stage 2: Barcode engine

← [01-scaffold](01-scaffold.md) · [Master](00-master.md) · Next: [03-totp-zappka](03-totp-zappka.md)

## Goal
Given `(symbology, text)`, produce a crisp, scannable image, or a clear validation error. This replaces bwip-js. It has to be cheap enough to run inside the widget extension, which has a memory limit of roughly 30 MB.

## Library choice (spike first)
1. **Primary: zxing-cpp** (`https://github.com/zxing-cpp/zxing-cpp`). It has an official iOS wrapper, exposed as the SPM product `ZXingCpp` (`ZXIBarcodeWriter`, `ZXIWriterOptions`, `ZXIFormat`).
   - Spike: add it to `project.yml` `packages:` and link it from both targets. Encode `"12345678"` as PDF417, QR, Code128 and EAN-13 (`5901234123457`), and check that the result is a `CGImage`.
   - Confirm the package path and product name while spiking. If SPM can't resolve the repo root, look for the Swift package under `wrappers/ios`.
2. **Fallback: ZXingObjC** (`https://github.com/zxingify/zxingobjc`, SPM). It has the same format set (`ZXMultiFormatWriter` → `ZXBitMatrix` → `ZXImage`). Switch to it if (1) won't build under Swift 6, won't link in the extension, or lacks a writer for PDF417.
3. Record which one won, and why, at the top of `BarcodeRenderer.swift` and in the master plan's Decisions table.

Hide the library behind `BarcodeRenderer`, so nothing else imports it. That way it can be swapped later.

## Files
```
Shared/Barcode/Symbology.swift
Shared/Barcode/BarcodeRenderer.swift
Shared/Barcode/BarcodeValidation.swift
CardsTests/BarcodeTests.swift
```

## `Symbology`
`enum Symbology: String, Codable, CaseIterable, Identifiable`, with these cases:
- `pdf417` (default)
- `qr`, `aztec`, `dataMatrix`
- `code128`, `code39`, `code93`
- `ean13`, `ean8`, `upcA`, `upcE`
- `itf`, `codabar`

The raw values are stable strings: they're persisted, so never rename them. Each case has:
- `displayName` ("PDF417", "QR Code", "EAN-13", …)
- `kind: .twoD | .stacked | .linear`. PDF417 is `.stacked`: wide, with a short aspect ratio. This drives the layout in stage 5.
- `isSquare`: QR, Aztec and DataMatrix are square.
- `showsHumanReadableText`: true for linear codes, because cashiers can type the digits in.
- `keyboard: .numberPad | .asciiCapable` for the editor
- `placeholder` sample text, used in the preview while the data field is empty

## Validation (`BarcodeValidation.swift`)
`func validate(_ text: String, for: Symbology) -> ValidationResult` returns `.ok`, `.warning(String)` or `.error(String)`:
- empty → error "Enter card number"
- **EAN-13:** 12 or 13 digits. With 12, the checksum is computed and appended (warning: "Check digit added: X"). With 13, the checksum is verified (error if it's wrong).
- **EAN-8:** 7 or 8 digits (same logic). **UPC-A:** 11 or 12 digits. **UPC-E:** 7 or 8 digits.
- **ITF:** even number of digits
- **Code39:** `[0-9A-Z \-.$/+%]` (uppercase letters are OK, with a hint that lowercase gets uppercased)
- **Codabar:** digits plus `-$:/.+`, with optional A–D start and stop characters
- **Code128 / QR / PDF417 / Aztec / DataMatrix:** any text. Warn on non-ASCII for Code128. Error if the text is too long for the symbology (catch the library's encode error and report it).

Also a `normalized(_ text:, for:)` that applies the auto-fixes: trim, uppercase for Code39, append check digits.

## `BarcodeRenderer`
```swift
enum BarcodeRenderer {
  /// Returns a 1-pixel-per-module image (no quiet zone baked in; views add padding).
  static func matrix(for text: String, symbology: Symbology) throws -> CGImage
}
```
- Ask the library for the **smallest native size** (width/height 0 or minimal, `margin: 0`), so every module is 1 px. Views scale it up with `.interpolation(.none)`. That keeps the image crisp at any widget size, and keeps it small in memory, which matters for the widget.
- PDF417: use the library's default columns and ECC, and check the aspect ratio is wide and short. If it's too tall, set a column count so it fits a medium widget's code area (about 3.5:1).
- 1D codes: height is 1 px from the library. The view stretches it vertically.
- Cache: an `NSCache` keyed by `"\(symbology.rawValue)|\(text)"`, so the editor preview doesn't re-encode on every redraw. The widget process gets its own cache.
- Errors: `BarcodeError.invalid(String)` and `.encodingFailed(String)`, with user-readable messages.

## Tests (`BarcodeTests.swift`)
- Validation table tests for each rule above, including EAN-13 checksum vectors (`590123412345` → `5901234123457`).
- **Round trip:** for each symbology Vision can read, render the matrix, upscale it ×8 with a white quiet zone into a bitmap, run `VNDetectBarcodesRequest`, and `#expect` the payload matches.
  - Vision reads: QR, Aztec, DataMatrix, PDF417, Code128, Code39, Code93, EAN-8, EAN-13, UPC-E, ITF-14 and Codabar. Skip any it can't decode, with a comment saying why.
- The Żappka-shaped payload (`https://srln.pl/view/dashboard?ploy=123456&loyal=000000`) round-trips as PDF417.
- Performance sanity: rendering a PDF417 of that payload 100× takes < 1 s.

## Acceptance
- [ ] Library chosen, and the decision recorded
- [ ] All validation and round-trip tests pass
- [ ] Nothing outside `Shared/Barcode/` imports the barcode library
