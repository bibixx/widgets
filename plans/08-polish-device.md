# Stage 8: Polish + real-device verification

← [07-widget](07-widget.md) · [Master](00-master.md)

## Goal
Make it pleasant, then prove it works where it matters: on your iPhone, at a Żabka till.

## Signing and install (needs the user)
1. Ask the user for their **Apple Team ID** (Xcode → Settings → Accounts). Put it in a git-ignored `local.yml` (see stage 1). A free personal team works for a personal device, but the build expires every 7 days; a paid team lasts a year.
2. Enable the App Group and Keychain sharing capabilities for both bundle IDs. Automatic signing with XcodeGen's entitlements should create them; check this in the Xcode Signing tab.
3. Install on the device: `xcodebuild -scheme Cards -destination 'platform=iOS,name=<device>' -allowProvisioningUpdates build`, then run it from Xcode for the first install.

## Device checklist
- [ ] **Scan tests:**
  - the phone camera or another phone reads every preset's widget (small, medium, large)
  - the Żabka till accepts the Żappka widget code
  - the other stores accept theirs
- [ ] **Rotation:** the Żappka widget's code changes every 30 s on the Home Screen, for 5+ minutes. Check again after locking the phone for 30 min, and in Low Power Mode. If entries stop rendering, shorten the horizon (stage 7 constant) and note the finding in the master plan.
- [ ] **Refresh button** and **tap → fullscreen** both work from a locked-then-unlocked phone.
- [ ] **Tinted and clear Home Screen modes:** the code stays black on white and scans. If not, adjust `CardView`'s rendering-mode handling in stage 5.
- [ ] **Widget sizes:** take Home Screen screenshots on this device and record the real small/medium/large point sizes in the preview size table (stage 6). The editor preview should match pixel for pixel.
- [ ] **Performance:** the widget extension stays under its memory limit (Xcode memory gauge with the widget attached), and `CardView` renders in < 5 ms.
- [ ] **Keychain while locked:** the widget still shows the Żappka code after a reboot plus first unlock, then while locked.

## Polish
- **App icon:** a simple card-with-barcode glyph. Provide the iOS 26 dark and tinted variants in the asset catalog.
- **Empty states and errors:** friendly copy everywhere; there are no dead ends.
- **Accessibility:**
  - VoiceOver labels ("Żappka card, rotating code, 17 seconds left")
  - Dynamic Type in the app UI (not inside the code area)
  - sufficient contrast for text in the app UI
- **Haptics:** a light tick on Żappka rotation in the checkout view, and a success haptic on save.
- **Localization:** English and Polish strings via a String Catalog (`Localizable.xcstrings`). Żabka is a Polish store.
- **Settings screen (minimal):** about/version, "Delete all data" (also clears the Keychain items).

## Wrap-up
- Update the master plan's Status and Decisions with anything learned: the chosen barcode library, the timeline horizon, and the real widget sizes.
- Write a README: what it is, build steps (`xcodegen generate`), and where the secrets live.
- Final commit and tag `v0.1.0`.

## Acceptance
- [ ] Every item in the device checklist is ticked, or documented with a workaround
- [ ] The user has used it at a till at least once
