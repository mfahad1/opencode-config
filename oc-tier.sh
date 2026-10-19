#!/usr/bin/env bash
# Detect whether an OpenCode Go subscription is active and point OPENCODE_CONFIG
# at the matching config. Source this, don't execute it.
#
#   subscribed  -> ~/.config/opencode/opencode.go.jsonc   (paid models)
#   not         -> leave unset, global opencode.jsonc wins (free models)
#
# Detection: `opencode models` lists opencode-go/* only when Go is connected.
# Result cached for a day. Force a re-check with:  oc-tier-refresh
# which also re-picks the newest, strongest models for each tier (oc-pick).

_oc_dir="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
_oc_cache="${XDG_CACHE_HOME:-$HOME/.cache}/opencode-tier"
_oc_maxage=86400

_oc_mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0; }

_oc_detect() {
  command -v opencode >/dev/null 2>&1 || { echo free; return; }
  # `command`: the wrapper below would re-source this file and recurse.
  if command opencode models 2>/dev/null | grep -q '^opencode-go/'; then echo paid; else echo free; fi
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

# Layers merged onto the tracked base config, in order:
#   opencode[.go].auto.json  models oc-pick chose at the last oc-tier-refresh
#   opencode.local.jsonc     per-machine overrides; model availability is
#                            regional, so a machine where a model is
#                            geo-blocked overrides just that role
# Both are untracked and never installed over. Echoes the config to use.
_oc_local="$_oc_dir/opencode.local.jsonc"
_oc_merged="${XDG_CACHE_HOME:-$HOME/.cache}/opencode-merged.json"

_oc_config() { # $1 = base config, $2 = its auto-picked layer
  if { [ -s "$2" ] || [ -s "$_oc_local" ]; } && [ -x "$_oc_dir/oc-merge" ]; then
    if "$_oc_dir/oc-merge" "$1" "$2" "$_oc_local" "$_oc_merged"; then
      printf '%s' "$_oc_merged"; return
    fi
  fi
  printf '%s' "$1"
}

case "$(_oc_tier)" in
  paid) export OPENCODE_CONFIG="$(_oc_config "$_oc_dir/opencode.go.jsonc" "$_oc_dir/opencode.go.auto.json")" ;;
  *)    _oc_free="$(_oc_config "$_oc_dir/opencode.jsonc" "$_oc_dir/opencode.auto.json")"
        # No override: leave it unset so the global opencode.jsonc wins as before.
        if [ "$_oc_free" = "$_oc_dir/opencode.jsonc" ]; then
          unset OPENCODE_CONFIG
        else
          export OPENCODE_CONFIG="$_oc_free"
        fi
        unset _oc_free ;;
esac

# Re-detect the tier and re-pick models for both tiers. Only the active tier
# is probed: Go models cannot answer without a subscription, so the Go picks
# are ranked from the catalogue alone until you subscribe.
oc-tier-refresh() {
  local t
  rm -f "$_oc_cache" "$_oc_merged"
  t=$(_oc_tier)
  if [ -x "$_oc_dir/oc-pick" ]; then
    echo "free models:"
    "$_oc_dir/oc-pick" free "$_oc_dir/opencode.auto.json" $([ "$t" = free ] && echo --probe)
    echo "go models:"
    "$_oc_dir/oc-pick" go "$_oc_dir/opencode.go.auto.json" $([ "$t" = paid ] && echo --probe)
  fi
  source "$_oc_dir/oc-tier.sh"
  echo "tier: $t | OPENCODE_CONFIG=${OPENCODE_CONFIG:-<free/global>}"
}

# Wrapper so a bare `opencode` always routes correctly.
opencode() { source "$_oc_dir/oc-tier.sh"; command opencode "$@"; }
