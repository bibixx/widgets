#!/usr/bin/env bash
# Build the app, install it on a connected iPhone and launch it. No version bump, no commit.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/phone.sh [--release] [--device NAME|UDID] [--no-launch] [-- LAUNCH_ARGS...]

  --release           build the Release configuration (default: Debug)
  --device NAME|UDID  target device (default: the only connected physical iPhone)
  --no-launch         install only
  -- LAUNCH_ARGS      passed to the app, e.g. -- -seed-samples

Team ID: $DEVELOPMENT_TEAM, or DEVELOPMENT_TEAM=... in the gitignored .env.local.
EOF
}

config=Debug
device=""
launch=true
launch_args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --release) config=Release; shift ;;
    --device) device="${2:?--device needs a value}"; shift 2 ;;
    --no-launch) launch=false; shift ;;
    --) shift; launch_args=("$@"); break ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

cd "$(git rev-parse --show-toplevel)"
# shellcheck source=scripts/_common.sh
source scripts/_common.sh

require_tools xcodegen xcodebuild xcrun python3
load_team_id
bundle_id=io.legiec.cards

# --- Pick the device ---------------------------------------------------------
devices_json="$(mktemp)"
trap 'rm -f "$devices_json"' EXIT
xcrun devicectl list devices --json-output "$devices_json" >/dev/null 2>&1 ||
  die "couldn't list devices (xcrun devicectl list devices)"

# Prints "udid<TAB>name" for connected physical iPhones matching $1 (name or UDID; empty = any).
# The script runs from stdin, so put the JSON path after "-".
match="$(python3 -I - "$devices_json" "$device" <<'PY'
import json, sys
path, want = sys.argv[1], sys.argv[2]
for d in json.load(open(path))["result"]["devices"]:
  hw, props, conn = d["hardwareProperties"], d["deviceProperties"], d["connectionProperties"]
  if hw.get("reality") != "physical" or hw.get("platform") != "iOS":
    continue
  if conn.get("pairingState") != "paired" or conn.get("tunnelState") == "unavailable":
    continue
  udid, name = hw.get("udid", ""), props.get("name", "")
  if want and want not in (udid, name):
    continue
  print(f"{udid}\t{name}")
PY
)"
count="$(grep -c . <<<"$match" || true)"
if [[ "$count" -eq 0 ]]; then
  die "no connected, paired iPhone${device:+ matching '$device'}. Plug it in (or same Wi-Fi), unlock it, trust this Mac, and turn on Developer Mode"
elif [[ "$count" -gt 1 ]]; then
  echo "$match" >&2
  die "more than one iPhone connected; pick one with --device NAME|UDID"
fi
udid="${match%%$'\t'*}"
name="${match#*$'\t'}"
step "Device: $name ($udid)"

# --- Build -------------------------------------------------------------------
step "Generating the project"
xcodegen generate --quiet
use_system_tools
mkdir -p build

step "Building $config (log: build/phone.log)"
if ! xcodebuild -scheme Cards -configuration "$config" -destination "platform=iOS,id=$udid" \
  -derivedDataPath build/phone -allowProvisioningUpdates build >build/phone.log 2>&1; then
  grep -E "error:" build/phone.log | sort -u | head -20 >&2 || true
  die "build failed; full log in build/phone.log"
fi
app="build/phone/Build/Products/$config-iphoneos/Cards.app"
[[ -d "$app" ]] || die "built app not found at $app"

# --- Install and launch ------------------------------------------------------
step "Installing"
xcrun devicectl device install app --device "$udid" "$app" >build/phone-install.log 2>&1 || {
  tail -20 build/phone-install.log >&2
  die "install failed; full log in build/phone-install.log"
}

if $launch; then
  step "Launching"
  if ! xcrun devicectl device process launch --device "$udid" --terminate-existing \
    "$bundle_id" ${launch_args[@]+"${launch_args[@]}"} >build/phone-launch.log 2>&1; then
    echo "warning: installed, but couldn't launch (is the phone locked?); see build/phone-launch.log"
    exit 0
  fi
fi

step "Done: $config build on $name"
