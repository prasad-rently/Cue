# cue

Umbrella router for the [Cue](../CLAUDE.md) project — discovers `cue-*` voice-assistant
engines on PATH and routes plain-text commands to the right one.

```bash
cue "turn on the lights"          # auto-routed
cue --alexa "set a timer"         # explicit vendor
cue --both "good morning"         # fan out to all engines
cue engines                       # list discovered engines
```

## Routing precedence (CUE_README.md §4)

1. explicit flag (`--alexa`/`--google`/`--both`)
2. vendor subcommand (`cue alexa …`)
3. per-device map (`[devices]` in `~/.config/cue/config.toml`)
4. default vendor (`CUE_DEFAULT` env or `default_vendor` key)
5. single-engine fallback
6. interactive prompt

```toml
# ~/.config/cue/config.toml
default_vendor = "alexa"

[devices]
"Living Room Echo" = "alexa"
"Bedroom Nest"     = "google"
```

## Commands

```bash
cue engines [--json]     # list engines discovered on PATH
cue doctor  [--json]     # aggregate each engine's health check
cue --both "<text>"      # parallel fan-out; exit 0 only if all engines succeed
cue alexa devices        # passthrough: exec cue-alexa devices
```

## Develop / validate

```bash
bats cue/tests/unit/router.bats      # 14 tests, uses stub engines as test data
shellcheck bin/cue lib/*.sh
```

Status: **P0–P3 implemented** (routing, discovery, `engines`, `doctor`, `--both`).
P4 (packaging) and P5 (completions) pending. Spec: [CUE_README.md](../CUE_README.md).
Engines are optional and discovered via PATH — `cue` works with 0, 1, or 2 installed.
