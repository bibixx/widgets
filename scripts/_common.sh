# Shared helpers for scripts/*.sh. Source it after `cd`-ing to the repo root.

die() { echo "error: $*" >&2; exit 1; }
step() { echo; echo "==> $*"; }

# Sets DEVELOPMENT_TEAM from the environment or the gitignored .env.local.
load_team_id() {
  if [[ -z "${DEVELOPMENT_TEAM:-}" && -f .env.local ]]; then
    DEVELOPMENT_TEAM="$(sed -n 's/^DEVELOPMENT_TEAM=//p' .env.local | tr -d '"'"'"' ' | head -1)"
  fi
  [[ -n "${DEVELOPMENT_TEAM:-}" ]] ||
    die "no team ID: export DEVELOPMENT_TEAM or put DEVELOPMENT_TEAM=<id> in .env.local"
  export DEVELOPMENT_TEAM
}

require_tools() {
  local tool
  for tool in "$@"; do command -v "$tool" >/dev/null || die "$tool not found"; done
}

# Homebrew's rsync 3.x breaks Xcode's copy steps ("Copy failed"); prefer the system tools.
use_system_tools() { export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"; }
