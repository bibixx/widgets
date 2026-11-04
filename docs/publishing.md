# Publishing to TestFlight

Cards goes out through TestFlight, either to the internal "Me" group or by public link. The App Store Connect record, the bundle name
and the home-screen / widget-gallery label are all "punktuj.se"; bundle ID `io.legiec.cards`.

Signing is automatic, and the team ID comes from the environment (never commit it).

## Every release

### 1. Bump the version
In `project.yml`:
- `CURRENT_PROJECT_VERSION`: **always** bump it (1 → 2 → …). App Store Connect rejects a build number
  it has already seen for the same version.
- `MARKETING_VERSION`: bump it when you want a new version line in TestFlight (e.g. `0.1.0` → `0.2.0`).
  A new marketing version triggers Beta App Review again for external testers.

Commit the bump.

### 2. Archive and upload
```sh
DEVELOPMENT_TEAM=<team id> xcodegen generate
export PATH="/usr/bin:$PATH"   # system rsync, see Troubleshooting
xcodebuild -scheme Cards -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/Cards.xcarchive -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath build/Cards.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath build/export -allowProvisioningUpdates
```
Look for `** ARCHIVE SUCCEEDED **` and then `Upload succeeded`. The upload uses the Apple ID signed in
under Xcode → Settings → Accounts. `ExportOptions.plist` (app-store-connect, upload, automatic signing)
is checked in, and `build/` is gitignored. Delete `build/` before re-running if an old archive is there.

From Xcode instead: choose the Any iOS Device destination, then Product → Archive → Organizer →
Distribute App → TestFlight & App Store. The rsync problem doesn't happen there.

If `xcodegen generate` changes `Cards/Info.plist` or `CardsWidget/Info.plist`, commit them too. They're
generated from `project.yml` but tracked in git.

### 3. Wait for processing
The build can take 10–15 minutes to appear under **TestFlight → Builds → iOS**, and processing can take
up to about 30 minutes. Apple emails you when it's done, or with `ITMS-…` issues if processing fails.

### 4. Distribute
- **Internal ("Me" group):** with Automatic Distribution on (group → Settings), it arrives without any
  action. Otherwise: click the build → Groups → **+** → Me.
- **External / public link:** add the build to the external group. A new marketing version waits for
  Beta App Review (usually under a day). Later builds of the same version usually go straight out.

Install and update through the TestFlight app on the iPhone.

### 5. Smoke test on device
This is the only place distribution signing gets exercised. Check that:
- adding a card works, and the widget shows it (App Group store read by the extension);
- Żappka's code rotates in the widget (secret read from the shared Keychain group);
- tapping a widget opens the card's link, or the editor when the card has no link.

## Testers

TestFlight builds expire after **90 days**, so upload a fresh build before then.

**Internal testers** (up to 100, no review): they must be on the App Store Connect team. In Users and Access
→ **+**, give them the **Marketing** role. It's the least powerful role that can be an internal tester;
Sales, Finance and Customer Support can't be. Limit their access to this app only and leave Create Apps
unticked. Once they accept, add them to an internal group under TestFlight.

**External testers and public link** (up to 10,000, needs Beta App Review): TestFlight → External Testing →
**+** → group → add the build. Fill in **Test Information** (beta description, feedback email, reviewer
contact; a privacy policy URL may be required: the app collects nothing, so a one-line page is enough).
After approval: group → **Public Link** → enable.

Review risk: Beta App Review applies the App Store guidelines, just less strictly. Two features could
draw a rejection: the Żappka rotating code (guideline 5.2.2, third-party services) and the bundled store
logos (5.2.1, trademarks). The way out is an external build without Żappka.

## One-time setup (already done)

Here for reference, or for a new machine or account.

- Paid Apple Developer Program membership.
- App IDs `io.legiec.cards` and `io.legiec.cards.widget` plus App Group `group.io.legiec.cards`.
  Automatic signing with `-allowProvisioningUpdates` registers them.
- App Store Connect app record (Apps → **+** → New App, bundle ID `io.legiec.cards`, primary language
  English (U.K.) to match the app's British spelling).
- `ITSAppUsesNonExemptEncryption: false` in the app's Info.plist (in `project.yml`), so builds skip
  the export-compliance question.
- Unique bundle names: "Cards" is taken, and ITMS-90129 checks both `CFBundleName` and
  `CFBundleDisplayName`, on the widget too. Both are `punktuj.se`.
- `TARGETED_DEVICE_FAMILY: "1"` set **per target** in `project.yml`. XcodeGen's iOS preset sets
  `"1,2"` on each target, which overrides a project-level value.

## Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| `Revoke certificate: Your account already has an Apple Development signing certificate for this machine, but its private key is not installed` | The certificate was created from another keychain or before a reinstall. Revoke it at developer.apple.com → Certificates (or Xcode → Settings → Accounts → Manage Certificates), then archive again. |
| `No profiles for 'io.legiec.cards' were found` | Usually follows the error above. Also check `-allowProvisioningUpdates` is passed and Xcode is signed in. |
| `exportArchive Copy failed` (logs show `rsync error: syntax or usage error`) | Homebrew's rsync 3.x is ahead of `/usr/bin` in `PATH`. Run the export with `export PATH="/usr/bin:$PATH"`. |
| `Invalid bundle … you need to include all of the … orientations to support iPad multitasking` | The build came out as an iPad app. Check `TARGETED_DEVICE_FAMILY = 1` with `xcodebuild -showBuildSettings`; it must be set per target. |
| Email: `ITMS-90129: The bundle uses a bundle name or display name that is already taken` | Another App Store app already uses one of the names. Change `CFBundleName` and/or `CFBundleDisplayName` (app and widget), bump the build, upload again. The upload itself succeeds; this only arrives by email. |
| Upload rejected: build number already used | Bump `CURRENT_PROJECT_VERSION`. |
| Build stuck at **Missing Compliance** | `ITSAppUsesNonExemptEncryption` is missing from the built Info.plist. For this build, click Manage and choose "None of the algorithms mentioned". |
| Build never appears, no email after ~30 min | Check the account holder's email for `ITMS-` messages. The distribution logs path is printed by `-exportArchive`. |
