---
name: phone
description: Build the app and install it on Bartek's connected iPhone with scripts/phone.sh. Use when asked to put, run, install or try the app on the phone or a real device.
---

# Run on the phone

Run `scripts/phone.sh`. It regenerates the project, builds (Debug by default), installs on the
connected iPhone with `devicectl`, and launches the app. It doesn't bump versions or commit anything.

```sh
scripts/phone.sh                      # Debug build on the only connected iPhone
scripts/phone.sh --release            # Release config (what TestFlight ships, minus distribution signing)
scripts/phone.sh -- -seed-samples     # pass launch arguments to the app
scripts/phone.sh --device "iPhone (Bartek)" --no-launch
```

Use a long timeout (about 10 min). The build log is in `build/phone.log`; install and launch logs are
next to it.

## Things to know
- It builds the working tree as it is, uncommitted changes included. That's usually what's wanted
  here, unlike `/testflight`.
- It uses the same bundle ID as TestFlight, so it **replaces** a TestFlight install on the phone.
  Cards and Żappka secrets survive (App Group and Keychain), and TestFlight can reinstall its
  build later. Mention this the first time.
- The team ID comes from `$DEVELOPMENT_TEAM` or `.env.local`, as with `/testflight`.
- "No connected, paired iPhone": ask the user to plug in or unlock the phone, trust this Mac, and
  turn on Developer Mode (Settings → Privacy & Security). A new phone also has to be registered;
  `-allowProvisioningUpdates` does that on the first build.
- "Couldn't launch" usually means the phone is locked. The app is installed; the user can open it.
- Signing errors: see Troubleshooting in `docs/publishing.md` (the certificate rows apply here too).
