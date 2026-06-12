# CLAUDE.md — Cue (root orchestration context)

This repo builds **Cue**: a family of POSIX CLI tools that pipe plain-text
commands from a terminal to voice assistants. One umbrella router + two engines.

## Components (each ships independently)

| Dir | Binary | What it is | Lang |
|-----|--------|-----------|------|
| [`cue/`](cue/) | `cue` | Umbrella router; auto-selects an engine | bash |
| [`cue-alexa/`](cue-alexa/) | `cue-alexa` | Amazon Alexa engine (wraps `alexa-remote-control`) | bash |
| [`cue-google/`](cue-google/) | `cue-google` | Google Assistant engine (gRPC) | bash + Python |

Engines MUST work **standalone**, with or without the umbrella. The only coupling
is the discovery contract (CUE_README.md §5): a `cue-*` binary on PATH that answers
`--cue-engine-info` with a JSON descriptor.

## Source of truth (read before building)

- `CUE_README.md` — umbrella spec (user contract §3, routing §4, discovery §5).
- `CUE_ALEXA_BRD.md` + `CUE_ALEXA_EXECUTION_PLAN.md` — Alexa engine.
- `CUE_GOOGLE_BRD.md` + `CUE_GOOGLE_EXECUTION_PLAN.md` — Google engine.
- `AGENT_RULES.md` — **non-negotiable rules for any agent touching this repo.**

Each plan's §8 is a list of sequential **execution prompts** (EP-1…EP-8). They are
the build unit. Run them in order; each ends with an Acceptance gate you must pass.

## How execution is tracked (cache + state)

This is the support layer — use it, don't bypass it:

- **State** — `.claude/state/execution-state.json` records every EP/phase's status.
  Read it at session start, update it at session end via `.claude/scripts/state.sh`.
  Slash commands: `/cue-status` (where are we) and `/cue-next` (do the next step).
- **Cache** — `.claude/cache/`:
  - `requirements-index.json` — resolve any `FR-*`/`NFR-*`/exit-code WITHOUT re-reading a BRD.
  - `decisions.md` — settled choices + still-OPEN questions (OPEN ones can block an EP).
  - `discovery.json` — TTL-bounded host/tooling probe.

The cache is an optimization, never an authority: if it disagrees with a BRD, the
BRD wins — regenerate the cache.

## Build order (see state file `suggested_order`)

1. `cue-alexa` (simplest, pure bash) → 2. `cue-google` (Python gRPC) →
3. `cue` umbrella (only adds value once an engine exists on PATH).

## Conventions

- All shell: `#!/usr/bin/env bash`, `set -euo pipefail`, must pass `shellcheck`.
- Config root is `~/.config/cue/`; each engine owns its `<vendor>/` subdir (mode 0700, secrets 0600).
- Never log secrets (cookies, passwords, TOTP seeds, OAuth/refresh tokens).
- Quote all user-supplied text passed to any shell/upstream — injection-safety is a hard requirement (FR-017 / FR-023).
- Exit codes are documented per engine (each plan's §10) — use the named constants, not magic numbers.
