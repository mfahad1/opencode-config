#!/usr/bin/env bash
# Detect whether an OpenCode Go subscription is active and point OPENCODE_CONFIG
# at the matching config. Source this, don't execute it.
#
#   subscribed  -> ~/.config/opencode/opencode.go.jsonc   (paid models)
#   not         -> leave unset, global opencode.jsonc wins (free models)
#
# Detection: `opencode models` lists opencode-go/* only when Go is connected.
# Result cached for a day. Force a re-check with:  oc-tier-refresh

_oc_dir="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
_oc_cache="${XDG_CACHE_HOME:-$HOME/.cache}/opencode-tier"
_oc_maxage=86400

_oc_mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0; }

_oc_detect() {
  command -v opencode >/dev/null 2>&1 || { echo free; return; }
  if opencode models 2>/dev/null | grep -q '^opencode-go/'; then echo paid; else echo free; fi
}

_oc_tier() {
  local now age
  now=$(date +%s)
  if [ -s "$_oc_cache" ]; then
    age=$(( now - $(_oc_mtime "$_oc_cache") ))
    if [ "$age" -lt "$_oc_maxage" ]; then cat "$_oc_cache"; return; fi
  fi
  local t; t=$(_oc_detect)
  mkdir -p "$(dirname "$_oc_cache")" && printf '%s' "$t" > "$_oc_cache"
  printf '%s' "$t"
}

# Per-machine overrides. Model availability is regional, so a machine where a
# model is geo-blocked can override just that role without forking the config.
# Untracked and never installed over; echoes the config to actually use.
_oc_local="$_oc_dir/opencode.local.jsonc"
_oc_merged="${XDG_CACHE_HOME:-$HOME/.cache}/opencode-merged.json"

_oc_config() { # $1 = base config
  if [ -s "$_oc_local" ] && [ -x "$_oc_dir/oc-merge" ]; then
    if "$_oc_dir/oc-merge" "$1" "$_oc_local" "$_oc_merged"; then
      printf '%s' "$_oc_merged"; return
    fi
    echo "oc-tier: ignoring $(basename "$_oc_local")" >&2
  fi
  printf '%s' "$1"
}

case "$(_oc_tier)" in
  paid) export OPENCODE_CONFIG="$(_oc_config "$_oc_dir/opencode.go.jsonc")" ;;
  *)    _oc_free="$(_oc_config "$_oc_dir/opencode.jsonc")"
        # No override: leave it unset so the global opencode.jsonc wins as before.
        if [ "$_oc_free" = "$_oc_dir/opencode.jsonc" ]; then
          unset OPENCODE_CONFIG
        else
          export OPENCODE_CONFIG="$_oc_free"
        fi
        unset _oc_free ;;
esac

oc-tier-refresh() { rm -f "$_oc_cache" "$_oc_merged"; source "$_oc_dir/oc-tier.sh"; echo "tier: $(cat "$_oc_cache") | OPENCODE_CONFIG=${OPENCODE_CONFIG:-<free/global>}"; }

# Wrapper so a bare `opencode` always routes correctly.
opencode() { source "$_oc_dir/oc-tier.sh"; command opencode "$@"; }
