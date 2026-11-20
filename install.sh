#!/usr/bin/env bash
#
# https://github.com/half0wl/kde-claude-usage-monitor-widget
#
# Install or upgrade the Claude Usage Monitor plasmoid for the current user.
#
# Run from a checkout:  ./install.sh
# Or straight from GitHub (downloads the repo first):
#   curl -fsSL https://raw.githubusercontent.com/half0wl/\
# kde-claude-usage-monitor-widget/main/install.sh | bash
set -euo pipefail
ID=cat.ray.kde-claude-usage-monitor-widget
REPO=half0wl/kde-claude-usage-monitor-widget
BRANCH=main

# ---- output ----------------------------------------------------------------
# Colours only on a terminal, and never when NO_COLOR is set.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  B=$'\e[1m' D=$'\e[2m' R=$'\e[31m' G=$'\e[32m' Y=$'\e[33m' C=$'\e[36m'
  X=$'\e[0m'
else
  B="" D="" R="" G="" Y="" C="" X=""
fi
step() { printf '  %s→%s %s\n' "$C" "$X" "$*"; }
ok() { printf '  %s✓%s %s\n' "$G" "$X" "$*"; }
warn() { printf '  %s!%s %s\n' "$Y" "$X" "$*"; }
die() {
  printf '  %s✗ %s%s\n\n' "$R" "$*" "$X" >&2
  exit 1
}
# Run kpackagetool6 quietly; show its output only if it fails.
kpkg() {
  local out
  if ! out="$(kpackagetool6 -t Plasma/Applet "$@" 2>&1)"; then
    printf '%s\n' "$out" | sed 's/^/    /' >&2
    die "kpackagetool6 $1 failed"
  fi
}

printf '\n%s%s%s\n' "$B" "https://github.com/$REPO" "$X"
printf '%sClaude Usage Monitor for KDE Plasma%s\n\n' "$D" "$X"

# ---- checks ----------------------------------------------------------------
command -v kpackagetool6 >/dev/null ||
  die "kpackagetool6 not found (KDE Plasma 6 is required)"

# ---- source ----------------------------------------------------------------
# When piped from curl there is no script file, so no package/ beside it:
# download and unpack the repo into a temporary directory instead.
src="${BASH_SOURCE[0]:-}"
if [ -n "$src" ] && [ -d "$(dirname "$src")/package" ]; then
  cd "$(dirname "$src")"
else
  command -v curl >/dev/null || die "curl not found"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  url="https://github.com/$REPO/archive/refs/heads/$BRANCH.tar.gz"
  step "Downloading ${D}$REPO@$BRANCH${X}"
  curl -fsSL "$url" | tar -xz -C "$tmp" --strip-components=1 ||
    die "Download failed: $url"
  cd "$tmp"
fi

version="$(sed -n 's/.*"Version": *"\([^"]*\)".*/\1/p' package/metadata.json)"

# ---- install / upgrade -----------------------------------------------------
if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -qx "$ID"; then
  step "Upgrading to ${B}v$version${X}"
  kpkg -u package
  ok "Upgraded"
  echo
  warn "Plasma must restart to load the new version."
  answer=n
  # Read from the terminal, not stdin: stdin is the script when piped.
  if { : </dev/tty; } 2>/dev/null; then
    read -r -p "  This will restart Plasma. Continue? [y/n] " answer \
      </dev/tty || true
  fi
  case "$answer" in
  [yY] | [yY][eE][sS])
    step "Restarting Plasma"
    if systemctl --user restart plasma-plasmashell 2>/dev/null; then
      ok "Plasma restarted"
    else
      warn "Couldn't restart Plasma. Log out and back in instead."
    fi
    ;;
  *)
    warn "Skipped. Restart later with:"
    printf '\n      %ssystemctl --user restart plasma-plasmashell%s\n' \
      "$B" "$X"
    ;;
  esac
else
  step "Installing ${B}v$version${X}"
  kpkg -i package
  ok "Installed"
  echo
  printf '  %sTo add the widget:%s\n' "$B" "$X"
  echo "    1. Right-click your panel"
  echo "    2. Add or Manage Widgets"
  echo "    3. Search for \"Claude Usage Monitor\""
  echo "    4. Drag it onto a panel"
fi
echo
