# opencode-config

Model routing for [OpenCode](https://opencode.ai). Free models when you have no
subscription, OpenCode Go models when you do, and a different model per kind of
task.

Why per task: Go's usage caps are **per model**, so spreading work across models
draws on several allowances instead of draining one.

## Install

Needs opencode itself (`curl -fsSL https://opencode.ai/install | bash`).

```bash
git clone https://github.com/mfahad1/opencode-config.git ~/Projects/opencode-config
cd ~/Projects/opencode-config && ./install.sh
```

Then open a new shell and run:

```bash
oc-tier-refresh   # detect free vs Go, pick the current best models
oc-doctor         # confirm the configured models answer from this machine
```

`install.sh` is safe to re-run. It wires zsh, bash and fish and backs up
anything it overwrites. To update later: `git pull && ./install.sh`.

## Daily use

Just run `opencode`. A wrapper picks the right config for your tier.

| Command | What it does |
|---|---|
| `oc-tier-refresh` | Re-detect your tier and re-pick models. Run it after subscribing, or when models start failing. |
| `oc-doctor` | Test every configured model from this machine |
| `opencode --agent write` | Writing agent: prose and docs, no shell access |

## How models are picked

`oc-tier-refresh` reads the live model list from [models.dev](https://models.dev)
and fills each role:

| Role | Gets |
|---|---|
| plan, build, write | The three strongest models, one each |
| explore, scout, general | The three newest fast models (flash, lite, mini…) |
| small (titles) | The cheapest fast model |

"Strongest" means newest for free models, since they all cost $0. For Go it
means highest price. It's a heuristic, not a benchmark.

On your active tier, each pick is test-called first. If one is geo-blocked or
times out, the next candidate is used. Go picks can't be tested until you
subscribe.

Picks are saved to `~/.config/opencode/opencode.auto.json` (free) and
`opencode.go.auto.json` (Go). If they're missing, the repo's `opencode.jsonc` /
`opencode.go.jsonc` are used as fallbacks.

## Override a model on one machine

Create `~/.config/opencode/opencode.local.jsonc` and name only the roles you
want to change:

```jsonc
{
  "agent": {
    "build": { "model": "opencode/big-pickle" }
  }
}
```

It wins over both the picks and the base config. `install.sh` never touches it.
Delete it to undo. Run `opencode models` to see what your account can reach.

Don't edit `~/.config/opencode/opencode.jsonc`, because `install.sh` overwrites it.

## Going on Go ($10/month)

1. Sign in at <https://opencode.ai/auth> and subscribe to Go.
2. In `opencode`, run `/connect`, choose OpenCode Go, and paste the key.
3. Run `oc-tier-refresh`. It should say `tier: paid`.

**Leave the Zen balance at $0 and auto-reload off.** Hitting a model's cap then
just blocks that model; nothing is charged. Auto-reload charges $20 whenever
the balance drops under $5, even past your usage limit.

## Privacy

Free models log or train on your prompts. Use them for throwaway work only,
never employer or confidential code. Go models are no-training; "contributor"
variants, which do train, are never picked.

## Troubleshooting

- **Still on free models after subscribing** → `oc-tier-refresh` (tier is cached for a day).
- **A model fails** → `oc-tier-refresh`, then `oc-doctor`. Free endpoints rate-limit, so one failure in a quick burst is normal.
- **fish** → uses `oc-tier.fish`. Sourcing `oc-tier.sh` from fish silently does nothing.

## Files

| File | Role |
|---|---|
| `opencode.jsonc` / `opencode.go.jsonc` | Base configs (free / Go), used as fallbacks |
| `oc-tier.sh` / `oc-tier.fish` | Tier detection, `opencode` wrapper, `oc-tier-refresh` |
| `bin/oc-pick` | Picks current models from models.dev |
| `bin/oc-merge` | Layers picks and your local override onto the base config |
| `bin/oc-doctor` | Tests the configured models |
| `install.sh` | Installer |

## Uninstall

```bash
rm ~/.config/opencode/{opencode.jsonc,opencode.go.jsonc,opencode.auto.json,opencode.go.auto.json,oc-tier.sh,oc-tier.fish,oc-merge,oc-pick} ~/.local/bin/oc-doctor
```

Then delete the `# opencode model routing` block from your shell rc.
