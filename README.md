# opencode-config

Tiered model routing for [OpenCode](https://opencode.ai). Uses free models when
you have no subscription, switches to OpenCode Go models when you do, and routes
each kind of task to a model suited to it.

## Why

OpenCode Go's usage limits are **per model, not one shared pool**. Running
everything on the strongest model drains its allowance and leaves every other
bucket untouched. Routing by task draws from independent allowances, so the
same $10 goes considerably further.

## Install

```bash
git clone https://github.com/mfahad1/opencode-config.git ~/Projects/opencode-config
cd ~/Projects/opencode-config && ./install.sh
```

One-liner, if you would rather not keep the checkout around:

```bash
gh repo clone mfahad1/opencode-config /tmp/occ && /tmp/occ/install.sh && rm -rf /tmp/occ
```

No git and no `gh` on the box? Copy the files to `~/.config/opencode/` by hand
and add this to your shell rc:

```bash
# ~/.zshrc or ~/.bashrc
[ -f "$HOME/.config/opencode/oc-tier.sh" ] && source "$HOME/.config/opencode/oc-tier.sh"
```

`oc-tier.sh` is bash syntax, so **fish** needs its own port instead — `oc-tier.fish`,
sourced from `~/.config/fish/config.fish`:

```fish
test -f "$HOME/.config/opencode/oc-tier.fish"; and source "$HOME/.config/opencode/oc-tier.fish"
```

`install.sh` wires zsh, bash and fish automatically. Sourcing `oc-tier.sh` from fish
does not work: fish cannot parse it, so `oc-tier-refresh` and the `opencode` wrapper
never get defined and `OPENCODE_CONFIG` stays unset (you silently stay on free models).

On a machine with no shell rc at all — a fresh macOS account ships no `~/.zshrc` —
the installer creates the rc for your login shell (`$SHELL`) rather than skipping.
It also creates `~/.local/bin` for `oc-doctor` if missing, and adds that directory
to your `PATH` in the same rc when it is not already there.

Open a new shell, then:

```bash
oc-tier-refresh   # detect free vs Go, show which config is active
oc-doctor         # verify the configured models work on THIS machine
```

Re-running `install.sh` is safe. It backs up anything it would overwrite.

To pull later changes on a machine you already set up:

```bash
cd ~/Projects/opencode-config && git pull && ./install.sh
```

## How the switch works

`oc-tier.sh` asks whether `opencode models` lists any `opencode-go/` entries,
which only happens once a Go subscription is connected. The result is cached
for a day, so shell startup stays near-instant.

- **Subscribed** → exports `OPENCODE_CONFIG` pointing at `opencode.go.jsonc`
- **Not subscribed** → exports nothing, so the global `opencode.jsonc` applies

The free config is the global default on purpose. If the wrapper never runs you
still land on something that works without an account, so there is no broken
state.

Force a re-check after subscribing with `oc-tier-refresh`.

## Switching on the Go tier

Go is a **$10/month subscription**, not a prepaid balance.

1. Sign in at <https://opencode.ai/auth> (GitHub or Google).
2. Subscribe to Go in the console and copy the API key.
3. Run `opencode`, then `/connect`, choose OpenCode Go, paste the key.
4. Run `oc-tier-refresh`. It should report `paid` and point at `opencode.go.jsonc`.

### Do not fund the Zen balance

Signing in creates a Zen account with a pay-as-you-go wallet. Leave it at zero.

Hitting a model's monthly cap **blocks** further calls on that model rather than
billing you, and that is the guardrail you want. Two settings would remove it,
both off by default: the `Use balance` fallback, and auto-reload.

Auto-reload is the trap. It charges $20 whenever the balance drops below $5, and
OpenCode's own docs note this can exceed a monthly usage limit you have set. The
limit constrains spending, not reloading. If you ever do add credit, disable
auto-reload first, and prefer one larger top-up: card fees are 4.4% plus a flat
$0.30, so small reloads are disproportionately expensive.

When you hit a cap, the usual fix is re-routing rather than paying. Moving daily
work off `glm-5.3` (a $15 cap) onto `kimi-k2.7-code` (a $60 cap) costs nothing.

## Routing

| Role | Free tier | Go tier |
|---|---|---|
| Plan | big-pickle | glm-5.3 |
| Build | big-pickle | kimi-k2.7-code |
| Explore / scout / general | nemotron-3.5-lightning | glm-5.3-flash, deepseek-v4-flash |
| Write | ling-3.0-flash-fin | longcat-2.0 |
| Titles / summaries | mimo-v2.5 | mimo-v2.5 |

`write` is a custom primary agent with bash denied and temperature raised, for
prose rather than code. Reach it with `opencode --agent write`, or Tab between
agents in the TUI.

## Portability warning

**Model availability varies by region and account.** Measured on macOS from
Canada, 2026-09-10:

| Model | Result |
|---|---|
| big-pickle | ok, 11s |
| mimo-v2.5-free | ok, 9s |
| ling-3.0-flash-fin-free | ok, 22s |
| nemotron-3.5-lightning-free | ok |
| nemotron-3-ultra-free | timed out past 75s |
| muse-spark 1.2 / 1.3 | geo-blocked |

Run `oc-doctor` on every new machine. If something fails, list what the account
can actually reach with `opencode models` and edit the config.

Free endpoints also rate-limit hard; rapid successive calls fail even on models
that work fine alone. That is expected, not a misconfiguration.

## Privacy

Every **free** model logs or trains on your prompts. Throwaway work only, never
anything confidential or employer-owned. The Go models are marked no-training
with zero-day retention, with the exception of the Muse Spark Contributor pair,
which are excluded here.

## Files

| File | Role |
|---|---|
| `opencode.jsonc` | Free tier, installed as the global default |
| `opencode.go.jsonc` | Go tier, selected via `OPENCODE_CONFIG` |
| `oc-tier.sh` | Detector, `opencode` wrapper, `oc-tier-refresh` |
| `bin/oc-doctor` | Verifies configured models work here |
| `install.sh` | Idempotent installer with backups |

## Uninstall

```bash
rm ~/.config/opencode/opencode.jsonc ~/.config/opencode/opencode.go.jsonc \
   ~/.config/opencode/oc-tier.sh ~/.local/bin/oc-doctor
```

Then remove the `# opencode model routing` block from your shell rc. Timestamped
backups of everything touched sit beside the originals.

## Notes

Measurements in this README were taken from one region on one account. They are
recorded so the numbers are interpretable, not because they generalise. Run
`oc-doctor` and trust its output over this table.

The configs contain no credentials. Your OpenCode API key lives in
`~/.local/share/opencode/auth.json`, written by `/connect`, and is never read or
copied by anything here.
