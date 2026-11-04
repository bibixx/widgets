---
name: testflight
description: Upload a new build of the app to TestFlight with scripts/publish.sh. Use when asked to publish, upload, ship or release to TestFlight, or to make a new build or version.
---

# Publish to TestFlight

Run `scripts/publish.sh`. It bumps `CURRENT_PROJECT_VERSION`, archives a Release build, checks the
archive, and uploads it. Then it commits the bump and tags it `testflight/<version>-<build>`. If any
step fails, it reverts the bump. Background and troubleshooting are in `docs/publishing.md`.

## Before running
- `git status`: if there are uncommitted changes, ask whether to commit them first or to upload them
  anyway with `--allow-dirty` (that build won't be tagged). Don't decide for the user.
- Pass `--version X.Y.Z` only when the user asks for a new version. A new version means another Beta
  App Review for external testers.
- The script reads the team ID from `$DEVELOPMENT_TEAM` or the gitignored `.env.local`. If both are
  missing, ask the user for it and offer to write `.env.local`. Never put it in a tracked file.
- Use `--dry-run` to check signing and archiving without uploading. It reverts the bump afterwards.

## Running
Archiving takes a few minutes, so use a long timeout (about 10 min). The script prints only errors and
a summary. The full logs are in `build/archive.log` and `build/export.log`.

## If it fails
Read the log it points to and match it against the Troubleshooting table in `docs/publishing.md`. Fix
what's in the repo yourself. Ask first before anything on the user's Apple account: revoking
certificates, changing App Store Connect, renaming the app.

## After a successful upload
Report the version and build, the commit and the tag. Don't push unless asked; suggest
`git push --follow-tags`. Remind the user that:
- processing takes 10–30 minutes, and Automatic Distribution then delivers the build to the internal
  "Me" group;
- problems found after the upload (e.g. ITMS-90129) arrive only by email. Ask them to forward the
  `ITMS-` code if one comes.

## Expiry reminder
TestFlight builds expire 90 days after upload, and the app and its widgets stop working. After every
real upload (not `--dry-run`), move the Google Calendar reminder so there's always exactly one, for the
newest build:
- Search the primary calendar for future events titled
  `punktuj.se: upload a new TestFlight build`.
- If one exists, update it. Otherwise create it. Never leave two.
- **All-day** on the upload date + 80 days, availability free, default reminders.
- Description, exactly this and nothing else:
  `TestFlight build <version> (<build>), uploaded <YYYY-MM-DD>, expires on <upload + 90 days> (90 days).`

If the Google Calendar tools aren't available, give the user the date (upload + 80 days) and suggest
they set a reminder themselves.
