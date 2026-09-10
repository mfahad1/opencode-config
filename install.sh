#!/usr/bin/env bash
# Install the OpenCode tiered model-routing config.
# Idempotent: safe to re-run. Existing files are backed up, never clobbered.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
STAMP="$(date +%Y%m%d-%H%M%S)"

say() { printf '  %s\n' "$*"; }

mkdir -p "$CFG"

for f in opencode.jsonc opencode.go.jsonc oc-tier.sh; do
  if [ -e "$CFG/$f" ] && ! cmp -s "$SRC/$f" "$CFG/$f"; then
    cp "$CFG/$f" "$CFG/$f.bak-$STAMP"
    say "backed up existing $f -> $f.bak-$STAMP"
  fi
  cp "$SRC/$f" "$CFG/$f"
  say "installed $f"
done
chmod +x "$CFG/oc-tier.sh"

# Wire into whichever shell rc exists. Idempotent by marker.
LINE='[ -f "$HOME/.config/opencode/oc-tier.sh" ] && source "$HOME/.config/opencode/oc-tier.sh"'
MARKER='# opencode model routing'
wired=0
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  [ -e "$rc" ] || continue
  if grep -qF "$MARKER" "$rc" 2>/dev/null; then
    say "already wired: $(basename "$rc")"; wired=1; continue
  fi
  cp "$rc" "$rc.bak-$STAMP"
  printf '\n%s: picks free or Go models based on subscription\n%s\n' "$MARKER" "$LINE" >> "$rc"
  say "wired $(basename "$rc") (backup: $(basename "$rc").bak-$STAMP)"; wired=1
done
[ "$wired" -eq 1 ] || say "WARNING: no .zshrc or .bashrc found; add this line yourself: $LINE"

# Optional: put oc-doctor on PATH if ~/.local/bin exists
if [ -d "$HOME/.local/bin" ]; then
  cp "$SRC/bin/oc-doctor" "$HOME/.local/bin/oc-doctor"
  chmod +x "$HOME/.local/bin/oc-doctor"
  say "installed oc-doctor to ~/.local/bin"
fi

rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/opencode-tier"

echo
echo "Done. Open a new shell, then:"
echo "  oc-tier-refresh   # detect free vs Go and show which config is active"
echo "  oc-doctor         # check the configured models actually work HERE"
echo
echo "Model availability is region- and account-dependent. Run oc-doctor on"
echo "every new machine; free models get geo-blocked and rate-limited."
