# Stage 3: TOTP + Żappka

← [02-barcode-engine](02-barcode-engine.md) · [Master](00-master.md) · Next: [04-model-storage](04-model-storage.md)

## Goal
Produce the exact Żappka code the Żabka scanner accepts: a standard RFC 6238 TOTP inside a fixed URL, encoded as PDF417. Self-contained, with no dependency on the old projects. Correctness is proven by the RFC test vectors here and a real till scan in stage 8.

## Files
```
Shared/Zappka/TOTP.swift
Shared/Zappka/Zappka.swift
Shared/Zappka/ZappkaCredentials.swift
CardsTests/TOTPTests.swift
CardsTests/ZappkaTests.swift
```

## `TOTP`
```swift
struct TOTP: Sendable {
  let secret: Data          // raw key bytes
  var digits = 6
  var period: TimeInterval = 30
  func code(at date: Date) -> String
  func window(containing date: Date) -> DateInterval   // [start, start+period)
}
```
The algorithm is RFC 6238 with HMAC-SHA1:
1. `counter = floor(unixSeconds / 30)`, as UInt64 big-endian, 8 bytes
2. `HMAC<Insecure.SHA1>(key: secret)` over the counter bytes (CryptoKit)
3. `offset = hash[19] & 0x0f`, then take 31 bits from `hash[offset..offset+3]`
4. `% 1_000_000`, zero-padded to 6 digits

`window(containing:)` is what the widget uses to align timeline entries (stage 7) and the countdown (stage 5).

## `ZappkaCredentials`
```swift
struct ZappkaCredentials: Codable, Hashable, Sendable {
  var userId: String
  var secretHex: String        // normalised: whitespace stripped, lowercased
}
```
- `static func normalizeSecret(_:) -> String` removes all whitespace and lowercases.
- `func validate() -> [Issue]`:
  - `userId` must not be empty
  - `secretHex` must not be empty
  - `secretHex` must be valid hex (`[0-9a-f]`)
  - `secretHex` must have an even length
  - Warn if it's shorter than 20 bytes or so. Don't fail: we don't know Żabka's real length, so log nothing and only show a hint.
- `var secretData: Data?`: hex → bytes
- This struct is the **seam for a future Żabka login**. Anything that produces `ZappkaCredentials` can fill the card.

## `Zappka`
```swift
enum Zappka {
  static let symbology: Symbology = .pdf417
  static func payload(userId: String, code: String) -> String   // "https://srln.pl/view/dashboard?ploy=\(userId)&loyal=\(code)"
  static func payload(for creds: ZappkaCredentials, at date: Date) -> String?
}
```
- The domain is `srln.pl` (confirmed current by the user; the older `zlgn.pl` is dead).
- Keep the host in one constant, so a future change is a one-line fix.
- Don't percent-encode `userId`: the payload the till accepted used plain interpolation, and encoding could change it. Add a validation hint if `userId` contains characters other than `[A-Za-z0-9_-]`.

## Tests
- RFC 6238 SHA1 vectors (ASCII secret `12345678901234567890` = hex `3132333435363738393031323334353637383930`), with 8-digit expectations truncated to 6:
  - T=59 → `287082`
  - T=1111111109 → `081804`
  - T=1234567890 → `005924`
- A made-up hex secret with spaces and uppercase gives the same code as its normalised form
- `normalizeSecret(" AB cd\n12 ")` → `"abcd12"`
- `window(containing:)` boundaries: t=30 → [30, 60), t=59.9 → [30, 60)
- `Zappka.payload` gives the exact string format
- Invalid hex or an odd-length secret → a validation issue, never a crash

## Acceptance
- [ ] RFC vectors pass
- [ ] Tests use made-up secrets only; no real credential appears anywhere in the repo
