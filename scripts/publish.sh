#!/usr/bin/env bash
# Bump the build number, archive a Release build and upload it to TestFlight.
# On success, commit the bump and tag it testflight/<version>-<build>. On failure, revert the bump.
# See docs/publishing.md.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/publish.sh [--version X.Y.Z] [--dry-run] [--allow-dirty]

  --version X.Y.Z  also set MARKETING_VERSION (the build number keeps counting up)
  --dry-run        bump, generate and archive, then revert; no upload, no commit
  --allow-dirty    build with uncommitted changes (commits only the bump, no tag)

Team ID: $DEVELOPMENT_TEAM, or DEVELOPMENT_TEAM=... in the gitignored .env.local.
EOF
}

new_version=""
dry_run=false
allow_dirty=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) new_version="${2:?--version needs a value}"; shift 2 ;;
    --dry-run) dry_run=true; shift ;;
    --allow-dirty) allow_dirty=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

cd "$(git rev-parse --show-toplevel)"
# shellcheck source=scripts/_common.sh
source scripts/_common.sh

# --- Preflight ---------------------------------------------------------------
require_tools xcodegen xcodebuild
load_team_id

if [[ -n "$new_version" && ! "$new_version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
  die "--version must look like 1.2 or 1.2.3, got '$new_version'"
fi

dirty=false
if [[ -n "$(git status --porcelain)" ]]; then
  dirty=true
  $allow_dirty || die "working tree has uncommitted changes; commit them or pass --allow-dirty"
  echo "warning: uploading uncommitted changes; the build won't match any commit and won't be tagged"
fi

# --- Bump --------------------------------------------------------------------
bump_files=(project.yml Cards/Info.plist CardsWidget/Info.plist)
build_num="$(sed -n 's/^ *CURRENT_PROJECT_VERSION: "\([0-9]*\)"$/\1/p' project.yml)"
version="$(sed -n 's/^ *MARKETING_VERSION: "\(.*\)"$/\1/p' project.yml)"
[[ -n "$build_num" && -n "$version" ]] ||
  die "couldn't read CURRENT_PROJECT_VERSION / MARKETING_VERSION from project.yml"

next_build=$((build_num + 1))
next_version="${new_version:-$version}"
tag="testflight/${next_version}-${next_build}"
git rev-parse -q --verify "refs/tags/$tag" >/dev/null && die "tag $tag already exists"

# Back up the files we touch so a failure restores them exactly, including uncommitted edits.
backup="$(mktemp -d)"
for f in "${bump_files[@]}"; do mkdir -p "$backup/$(dirname "$f")"; cp "$f" "$backup/$f"; done
uploaded=false
restore() {
  if ! $uploaded; then
    for f in "${bump_files[@]}"; do cp "$backup/$f" "$f"; done
    echo "Reverted the version bump."
  fi
  rm -rf "$backup"
}
trap restore EXIT

sed -i '' "s/^\( *CURRENT_PROJECT_VERSION: \)\"$build_num\"$/\1\"$next_build\"/" project.yml
sed -i '' "s/^\( *MARKETING_VERSION: \)\"$version\"$/\1\"$next_version\"/" project.yml
step "$version ($build_num) → $next_version ($next_build)"

# --- Generate and archive ----------------------------------------------------
step "Generating the project"
xcodegen generate --quiet
use_system_tools
mkdir -p build
rm -rf build/Cards.xcarchive build/export
archive=build/Cards.xcarchive

step "Archiving (log: build/archive.log)"
if ! xcodebuild -scheme Cards -configuration Release -destination 'generic/platform=iOS' \
  -archivePath "$archive" -allowProvisioningUpdates archive >build/archive.log 2>&1; then
  grep -E "error:" build/archive.log | sort -u | head -20 >&2 || true
  die "archive failed; full log in build/archive.log (see Troubleshooting in docs/publishing.md)"
fi

# --- Sanity-check the archive ------------------------------------------------
app_plist="$archive/Products/Applications/Cards.app/Info.plist"
widget_plist="$archive/Products/Applications/Cards.app/PlugIns/CardsWidget.appex/Info.plist"
pb() { /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null || true; }

families="$(pb "$app_plist" UIDeviceFamily | tr -d ' \n')"
[[ "$families" == "Array{1}" ]] ||
  die "app targets more than iPhone (UIDeviceFamily: $families); set TARGETED_DEVICE_FAMILY per target"
[[ "$(pb "$app_plist" CFBundleVersion)" == "$next_build" ]] ||
  die "archived CFBundleVersion isn't $next_build"
[[ "$(pb "$app_plist" ITSAppUsesNonExemptEncryption)" == "false" ]] ||
  die "ITSAppUsesNonExemptEncryption isn't false; the build would wait at Missing Compliance"

echo "App:    $(pb "$app_plist" CFBundleName) / $(pb "$app_plist" CFBundleDisplayName)"
echo "Widget: $(pb "$widget_plist" CFBundleName) / $(pb "$widget_plist" CFBundleDisplayName)"

if $dry_run; then
  step "Dry run: archive OK, skipping upload"
  exit 0
fi

# --- Upload ------------------------------------------------------------------
step "Uploading to App Store Connect (log: build/export.log)"
xcodebuild -exportArchive -archivePath "$archive" -exportOptionsPlist ExportOptions.plist \
  -exportPath build/export -allowProvisioningUpdates >build/export.log 2>&1 || true
if ! grep -q "Upload succeeded" build/export.log; then
  grep -E "error" build/export.log | head -20 >&2 || true
  die "upload failed; full log in build/export.log"
fi
uploaded=true

# --- Commit and tag ----------------------------------------------------------
if [[ -n "$new_version" ]]; then msg="Release $next_version ($next_build)"; else msg="Bump to build $next_build"; fi
git add "${bump_files[@]}"
git commit -q -m "$msg" -- "${bump_files[@]}"
if $dirty; then
  echo "Committed \"$msg\" (not tagged: the upload included uncommitted changes)."
else
  git tag "$tag"
  echo "Committed \"$msg\" and tagged $tag."
fi

step "Uploaded $next_version ($next_build)"
cat <<EOF
- Processing takes 10–30 min; the build then appears under TestFlight → Builds.
- Problems found after upload (e.g. ITMS-90129) arrive only by email.
- Nothing was pushed. To push: git push --follow-tags
EOF
