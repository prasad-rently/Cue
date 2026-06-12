# cue-alexa — Command reference & interactions

Every command, its flags, expected output, and exit codes. For a guided
validation run (no Amazon account needed) see [`../VALIDATION.md`](../VALIDATION.md).

## Global flags

| Flag | Meaning |
|------|---------|
| `--device <name>` | target a single Echo by friendly name |
| `--all` | broadcast to every Echo |
| `--group <name>` | target a device group |
| `--mode text\|speak\|routine` | command mode (default `text`) |
| `--json` | machine-readable JSON output |
| `--quiet` | suppress non-error stdout |
| `--verbose`, `-v` | debug logging to stderr |
| `--version` / `--help` | version / help |
| `--cue-engine-info` | Cue discovery descriptor (JSON) |

Resolution precedence for device/mode/region: **flag > env var > config file**.
Env vars: `ALEXA_DEFAULT_DEVICE`, `ALEXA_DEFAULT_MODE`, `ALEXA_REGION`.

## Authentication

```bash
cue-alexa login                      # interactive: choose credentials or cookie
cue-alexa login --credentials        # email + password + TOTP secret (prompted)
cue-alexa login --cookie ~/cookie.txt  # import a Netscape-format cookie file
```
Secrets are written only to `~/.config/cue/alexa/` (dir `0700`, files `0600`) and
are never printed to stdout.

## Sending commands

```bash
# Text (NLU-interpreted, as if spoken) — the default mode
cue-alexa --device "Living Room" "turn on the lights"

# Speak (TTS, no interpretation)
cue-alexa --mode speak --device "Kitchen" "dinner is ready"

# Trigger a routine by its Alexa-app name
cue-alexa --mode routine --device "Bedroom" "Good Night"

# Broadcast to every Echo / to a group
cue-alexa --all "good morning"
cue-alexa --group "Downstairs" "we're leaving"

# Use the configured default device (no --device needed)
cue-alexa config set default_device "Living Room"
cue-alexa "what time is it"

# Machine-readable result
cue-alexa --json --device "Kitchen" "set a timer for 5 minutes"
# -> {"status":"ok","mode":"text","text":"set a timer for 5 minutes","response":"..."}
```

## Discovery & diagnostics

```bash
cue-alexa devices               # table of device names
cue-alexa devices --json        # {"devices":["Living Room","Bedroom Echo",...]}
cue-alexa devices --refresh     # bypass the 24h cache and re-query
cue-alexa doctor                # health: auth, region, device reachability
cue-alexa doctor --json         # {"auth":"ok","region":"...","device_count":3,"healthy":true}
cue-alexa doctor --offline      # skip network checks (e.g. on a plane)
cue-alexa groups                # (listing not exposed by upstream — see note)
cue-alexa routines              # (listing not exposed by upstream — see note)
```

> **Note (NFR-008 graceful degradation):** the upstream `alexa-remote-control`
> exposes no endpoint to *list* groups or routines — only to *trigger* them by
> name. So `groups`/`routines` return an empty list with an explanatory note;
> address a group with `--group "<name>"` and trigger a routine with
> `--mode routine "<name>"`. Tracked in `.claude/cache/decisions.md`.

## Configuration

```bash
cue-alexa config set default_device "Living Room"
cue-alexa config set region amazon.in
cue-alexa config get default_device          # -> Living Room
```
Config lives at `~/.config/cue/alexa/config.toml` (flat `key = "value"` TOML).

## Exit codes (CUE_ALEXA_EXECUTION_PLAN.md §10)

| Code | Meaning | Code | Meaning |
|------|---------|------|---------|
| 0 | success | 21 | device offline |
| 1 | generic failure | 30 | upstream call error |
| 2 | invalid usage | 31 | upstream unparseable |
| 10 | auth expired/missing | 40 | network error |
| 11 | auth refresh failed | 41 | Amazon rate-limit (429) |
| 20 | device not found | 99 | not implemented (dev) |

```bash
cue-alexa --device Kitchen "turn off the lights" || echo "failed with code $?"
```
