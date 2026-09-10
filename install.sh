#!/usr/bin/env bash
# Install the OpenCode tiered model-routing config.
# Idempotent: safe to re-run. Existing files are backed up, never clobbered.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
STAMP="$(date +%Y%m%d-%H%M%S)"

say() { printf '  %s\n' "$*"; }

mkdir -p "$CFG"

for f in opencode.jsonc opencode.go.jsonc oc-tier.sh oc-tier.fish; do
  if [ -e "$CFG/$f" ] && ! cmp -s "$SRC/$f" "$CFG/$f"; then
    cp "$CFG/$f" "$CFG/$f.bak-$STAMP"
    say "backed up existing $f -> $f.bak-$STAMP"
  fi
  cp "$SRC/$f" "$CFG/$f"
  say "installed $f"
done
chmod +x "$CFG/oc-tier.sh"

# oc-tier.sh/.fish call this to layer opencode.local.jsonc onto the base config.
cp "$SRC/bin/oc-merge" "$CFG/oc-merge"
chmod +x "$CFG/oc-merge"
say "installed oc-merge"

# opencode.local.jsonc is this machine's, never ours: it is deliberately absent
# from the copy loop above so a re-run cannot clobber regional model overrides.
if [ -s "$CFG/opencode.local.jsonc" ]; then
  say "kept your opencode.local.jsonc (overrides still applied)"
fi

# Wire into whichever shell rc exists. Idempotent by marker.
# oc-tier.sh is bash syntax and fish cannot parse it, so fish gets its own port.
LINE='[ -f "$HOME/.config/opencode/oc-tier.sh" ] && source "$HOME/.config/opencode/oc-tier.sh"'
FISH_LINE='test -f "$HOME/.config/opencode/oc-tier.fish"; and source "$HOME/.config/opencode/oc-tier.fish"'
MARKER='# opencode model routing'
FISH_RC="${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish"
wired=0

# Append the source line, creating the rc if it does not exist yet. A fresh
# macOS account ships no ~/.zshrc, so refusing to create one meant the
# installer silently wired nothing.
wire() { # $1=rc file, $2=line to append
  local bk=""
  mkdir -p "$(dirname "$1")"
  if [ ! -e "$1" ]; then
    touch "$1"
    say "created $(basename "$1")"
  elif grep -qF "$MARKER" "$1" 2>/dev/null; then
    say "already wired: $(basename "$1")"
    wired=1
    return 0
  elif [ -s "$1" ]; then
    cp "$1" "$1.bak-$STAMP"
    bk=" (backup: $(basename "$1").bak-$STAMP)"
  fi
  printf '\n%s: picks free or Go models based on subscription\n%s\n' "$MARKER" "$2" >> "$1"
  say "wired $(basename "$1")$bk"
  wired=1
}

# Wire every rc that already exists, so multi-shell machines all get routing.
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  if [ -e "$rc" ]; then wire "$rc" "$LINE"; fi
done
if [ -e "$FISH_RC" ] || command -v fish >/dev/null 2>&1; then
  wire "$FISH_RC" "$FISH_LINE"
fi

# Nothing to wire: create the rc for the login shell instead of giving up.
if [ "$wired" -eq 0 ]; then
  case "$(basename "${SHELL:-/bin/zsh}")" in
    fish)
      wire "$FISH_RC" "$FISH_LINE"
      ;;
    bash)
      wire "$HOME/.bashrc" "$LINE"
      # macOS login bash reads .bash_profile, never .bashrc.
      if [ ! -e "$HOME/.bash_profile" ]; then
        printf '[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"\n' > "$HOME/.bash_profile"
        say "created .bash_profile (sources .bashrc)"
      fi
      ;;
    *)
      wire "$HOME/.zshrc" "$LINE"
      ;;
  esac
fi

# Put oc-doctor on PATH. Create ~/.local/bin if needed: on a fresh machine it
# does not exist, and skipping it left oc-doctor uninstalled with no warning.
mkdir -p "$HOME/.local/bin"
cp "$SRC/bin/oc-doctor" "$HOME/.local/bin/oc-doctor"
chmod +x "$HOME/.local/bin/oc-doctor"
say "installed oc-doctor to ~/.local/bin"

# Installing a binary into a directory the shell cannot search is useless, so
# put it on PATH too. Separate marker: an rc wired by an older run still needs
# this, and a machine that already has the directory on PATH is left alone.
PATH_MARKER='# opencode: oc-doctor on PATH'
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
FISH_PATH_LINE='fish_add_path "$HOME/.local/bin"'

add_path_line() { # $1=rc file, $2=line to append
  if [ ! -e "$1" ]; then return 0; fi
  if grep -qF "$PATH_MARKER" "$1" 2>/dev/null; then
    say "already on PATH via $(basename "$1")"
    return 0
  fi
  printf '\n%s\n%s\n' "$PATH_MARKER" "$2" >> "$1"
  say "added ~/.local/bin to PATH in $(basename "$1")"
}

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *)
    for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
      add_path_line "$rc" "$PATH_LINE"
    done
    add_path_line "$FISH_RC" "$FISH_PATH_LINE"
    ;;
esac

# This repo ships config for opencode, not opencode itself. Say so plainly
# rather than letting oc-doctor fail with a bare "opencode not on PATH".
if ! command -v opencode >/dev/null 2>&1; then
  if [ -x "$HOME/.opencode/bin/opencode" ]; then
    say "WARNING: opencode is installed at ~/.opencode/bin but not on your PATH."
    say "         Add it:  echo 'export PATH=\"\$HOME/.opencode/bin:\$PATH\"' >> ~/.zshrc"
  else
    say "WARNING: opencode is not installed; this repo only configures it."
    say "         Install it:  curl -fsSL https://opencode.ai/install | bash"
  fi
fi

rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/opencode-tier"

echo
echo "Done. Open a new shell, then:"
echo "  oc-tier-refresh   # detect free vs Go and show which config is active"
echo "  oc-doctor         # check the configured models actually work HERE"
echo
echo "Model availability is region- and account-dependent. Run oc-doctor on"
echo "every new machine; free models get geo-blocked and rate-limited."
