# Cue — Project Overview

**Project:** Cue
**Tagline:** Cue the lights — text-to-voice-assistant from your terminal
**Version:** 0.1 (Draft)
**Date:** 8 June 2026
**Author:** Gokul
**Status:** Draft

---

## 1. What this is

Cue is a small family of POSIX command-line tools that let a power user pipe plain-text commands from a terminal to their voice assistants — Amazon Alexa and Google Assistant today, with room to grow. The user types `cue "turn on the lights"` and Cue routes the command to whichever ecosystem owns the target device.

The name comes from stagecraft: a stage manager calls cues from the wings, and the lights, music, and actors respond on command. The user-as-stage-manager metaphor fits the use case exactly — silently directing what happens in the room without having to perform on stage themselves.

---

## 2. Components

Cue is split across three repositories. Each ships independently and works on its own; the umbrella adds cross-vendor routing on top.

| Repo          | Binary       | Purpose                                                          |
|---------------|--------------|------------------------------------------------------------------|
| `cue`         | `cue`        | Umbrella router; auto-selects an engine based on config / flags  |
| `cue-alexa`   | `cue-alexa`  | Amazon Alexa engine (bash; wraps `alexa-remote-control` upstream) |
| `cue-google`  | `cue-google` | Google Assistant engine (bash front-end + Python core; gRPC)     |

Each engine is documented in its own BRD + execution plan:
- `CUE_ALEXA_BRD.md`, `CUE_ALEXA_EXECUTION_PLAN.md`
- `CUE_GOOGLE_BRD.md`, `CUE_GOOGLE_EXECUTION_PLAN.md`

This document covers the umbrella only.

---

## 3. User contract

```bash
# Auto-routed by default vendor (set in config or via env CUE_DEFAULT)
cue "turn on the lights"

# Explicit vendor selection
cue --alexa "set a timer for 5 minutes"
cue --google "what's on my calendar"

# Fan-out to all installed engines
cue --both "good morning"

# Vendor-scoped subcommands (passthrough to the engine binary)
cue alexa devices
cue alexa routines
cue google setup
cue google device-model list

# Health check across all installed engines
cue doctor

# Show which engines are discoverable on PATH
cue engines
```

**Design rule:** anything not explicitly handled by the umbrella is forwarded verbatim to the selected engine. The umbrella does not parse engine-specific flags — it sees `cue alexa --device "Bedroom" "..."`, identifies `alexa` as a vendor subcommand, and execs `cue-alexa --device "Bedroom" "..."`.

---

## 4. Routing logic

In order of precedence (highest first):

1. **Explicit vendor flag** — `--alexa`, `--google`, `--both`
2. **Vendor subcommand** — first positional arg matches a known vendor (`alexa`, `google`)
3. **Per-device routing** — if config maps the target device name to a specific vendor, use it
4. **Default vendor** — `CUE_DEFAULT` env var, or `default_vendor` key in `~/.config/cue/config.toml`
5. **Single-engine fallback** — if only one engine is installed, use it
6. **Prompt** — interactive: ask the user which vendor to use, with option to save as default

`--both` runs the engines in parallel and aggregates exit codes (non-zero if any failed, with engine-specific output on stderr).

---

## 5. Engine discovery

The umbrella discovers engines by looking for binaries on `PATH` matching `cue-*`. Each engine MUST:

- Be invocable as a standalone binary independent of the umbrella
- Respond to `--cue-engine-info` with a JSON descriptor:
  ```json
  {
    "name": "alexa",
    "version": "0.1.0",
    "description": "Amazon Alexa engine for Cue",
    "supports": ["text", "speak", "routine", "device", "group"]
  }
  ```
- Accept the text payload as its final positional argument
- Honour `--json`, `--quiet`, `--verbose` as documented in each engine's BRD
- Return documented exit codes (each engine maps its own; the umbrella surfaces them)

This contract is the only coupling between the umbrella and engines. Adding a future engine (HomeKit, SmartThings, Sonos) means dropping a `cue-<vendor>` binary on PATH that satisfies it.

---

## 6. Configuration

Shared config root: `~/.config/cue/`

```
~/.config/cue/
├── config.toml          # Umbrella config (default vendor, device→vendor map)
├── alexa/               # Alexa engine state (owned by cue-alexa)
│   ├── config.toml
│   ├── cookie.txt
│   └── devices.cache.json
└── google/              # Google engine state (owned by cue-google)
    ├── .venv/
    ├── config.toml
    ├── credentials.json
    └── ...
```

The umbrella owns `config.toml` at the root. Each engine owns its subdirectory entirely and is responsible for migrating older `~/.config/cue-alexa/` or `~/.config/cue-google/` paths to the namespaced location on first run after upgrade.

Example `~/.config/cue/config.toml`:
```toml
default_vendor = "alexa"

[devices]
# Device names → preferred vendor (used for per-device routing)
"Living Room Echo" = "alexa"
"Bedroom Nest"     = "google"
"Garage"           = "google"
```

---

## 7. Roadmap (umbrella only)

| Phase | Scope | Estimate |
|-------|-------|----------|
| P0    | Single-file bash `cue` that exec's the right engine based on `--alexa`/`--google` flags | 2h |
| P1    | Engine discovery via `--cue-engine-info`; `cue engines`; `cue doctor` aggregator | 3h |
| P2    | Per-device routing table; default-vendor fallback chain; interactive prompt | 2h |
| P3    | `--both` parallel fan-out with proper exit-code aggregation | 2h |
| P4    | Homebrew formula + curl `install.sh` for Linux | 2h |
| P5    | Shell completions (bash, zsh) | 1h |

Total estimate: **~12 hours** for a v0.1.0 umbrella.

---

## 8. Execution prompt — umbrella bootstrap

```
You are building the `cue` umbrella router from CUE_README.md
section 3 (user contract), section 4 (routing logic), and section 5
(engine discovery).

Tasks:
1. Create a new repo `cue` with the structure:
     bin/cue
     lib/discover.sh
     lib/route.sh
     lib/config.sh
     share/completions/
     docs/
     CUE_README.md (copy from this file)
2. Implement bin/cue as a bash script that:
   - Parses --alexa, --google, --both, --help, --version
   - Recognises `alexa`, `google`, `doctor`, `engines` as subcommands
   - Discovers engines on PATH via `cue-*` glob + `--cue-engine-info`
   - Routes per section 4 precedence rules
   - For unknown subcommands, exec's the engine with all original args
3. Implement `cue engines` listing discovered engines with their
   descriptors.
4. Implement `cue doctor` that runs each discovered engine's
   `doctor --json` and aggregates the results.
5. Implement `cue --both <text>` running both engines in parallel
   with proper exit-code aggregation (0 only if all succeed).

Acceptance:
- `cue --version` works with no engines installed
- `cue engines` correctly lists 0, 1, or 2 engines depending on what
  is on PATH
- `cue --alexa "test"` exec's cue-alexa when present, prints a clear
  error otherwise
- `cue "test"` follows the section 4 precedence chain on the author's
  setup
- shellcheck passes
```

---

## 9. Naming rationale

A few candidates were considered before settling on Cue:

| Name      | Pro | Con |
|-----------|-----|-----|
| **Cue**   | Stagecraft metaphor matches use case; short, one-syllable; reads well as a verb | Slight overload with Go's `cuelang` config language |
| Aside     | Theatrical aside — speaking without others hearing — captures silent communication | Reads as a preposition; harder to alias |
| Sotto     | From *sotto voce* — softly, not aloud | Italian; less immediately readable |
| Prompter  | The theatre prompter feeds lines to actors | Overloaded post-LLM with "prompts" |
| Whisper   | Quiet command from operator to actors | OpenAI Whisper collision |

Cue won on metaphor fit, length, and verb-readability. The `cuelang` overload is contained to a different domain (config language vs. CLI tool) and unlikely to confuse users in practice.

---

## 10. Out of scope (umbrella)

- The umbrella does not implement any voice-assistant API logic — that lives in the engines
- The umbrella does not handle auth — each engine owns its own auth
- The umbrella does not parse or interpret command text — it forwards verbatim
- The umbrella does not maintain device caches — it queries engines on demand and caches the *discovery* result only

---

*End of Cue README v0.1*
