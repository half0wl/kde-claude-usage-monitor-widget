#!/usr/bin/env bash
#
# https://github.com/half0wl/kde-claude-usage-monitor-widget
#
# Uninstall the Claude Usage Monitor plasmoid for the current user.
# Remove the widget from your panels first.
set -euo pipefail
ID=cat.ray.kde-claude-usage-monitor-widget
REPO=half0wl/kde-claude-usage-monitor-widget

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

printf '\n%s%s%s\n' "$B" "https://github.com/$REPO" "$X"
printf '%sClaude Usage Monitor for KDE Plasma%s\n\n' "$D" "$X"

command -v kpackagetool6 >/dev/null ||
  die "kpackagetool6 not found (KDE Plasma 6 is required)"

if ! kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -qx "$ID"; then
  ok "Not installed, nothing to do"
  echo
  exit 0
fi

step "Removing ${B}$ID${X}"
if ! out="$(kpackagetool6 -t Plasma/Applet -r "$ID" 2>&1)"; then
  printf '%s\n' "$out" | sed 's/^/    /' >&2
  die "kpackagetool6 -r failed"
fi
ok "Uninstalled"
echo
warn "If the widget is still on a panel, remove it there too"
printf '    %s(right-click it → Remove).%s\n' "$D" "$X"
echo
