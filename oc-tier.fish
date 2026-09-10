# fish port of oc-tier.sh. Source this from config.fish, don't execute it.
#
#   subscribed  -> ~/.config/opencode/opencode.go.jsonc   (paid models)
#   not         -> leave unset, global opencode.jsonc wins (free models)
#
# Detection: `opencode models` lists opencode-go/* only when Go is connected.
# Result cached for a day. Force a re-check with:  oc-tier-refresh

if test -n "$XDG_CONFIG_HOME"
    set -g _oc_dir $XDG_CONFIG_HOME/opencode
else
    set -g _oc_dir $HOME/.config/opencode
end
if test -n "$XDG_CACHE_HOME"
    set -g _oc_cache $XDG_CACHE_HOME/opencode-tier
else
    set -g _oc_cache $HOME/.cache/opencode-tier
end
set -g _oc_maxage 86400

function _oc_mtime
    stat -f %m $argv[1] 2>/dev/null; or stat -c %Y $argv[1] 2>/dev/null; or echo 0
end

function _oc_detect
    if not command -q opencode
        echo free
        return
    end
    if command opencode models 2>/dev/null | grep -q '^opencode-go/'
        echo paid
    else
        echo free
    end
end

function _oc_tier
    if test -s "$_oc_cache"
        set -l age (math (date +%s) - (_oc_mtime $_oc_cache))
        if test $age -lt $_oc_maxage
            cat $_oc_cache
            return
        end
    end
    set -l t (_oc_detect)
    mkdir -p (dirname $_oc_cache); and printf '%s' $t >$_oc_cache
    printf '%s' $t
end

function _oc_apply
    switch (_oc_tier)
        case paid
            set -gx OPENCODE_CONFIG $_oc_dir/opencode.go.jsonc
        case '*'
            set -e OPENCODE_CONFIG
    end
end

_oc_apply

function oc-tier-refresh
    rm -f $_oc_cache
    _oc_apply
    if set -q OPENCODE_CONFIG
        echo "tier: "(cat $_oc_cache)" | OPENCODE_CONFIG=$OPENCODE_CONFIG"
    else
        echo "tier: "(cat $_oc_cache)" | OPENCODE_CONFIG=<free/global>"
    end
end

# Wrapper so a bare `opencode` always routes correctly.
function opencode
    _oc_apply
    command opencode $argv
end
