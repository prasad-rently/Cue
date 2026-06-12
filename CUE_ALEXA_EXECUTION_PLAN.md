# Cue — Alexa Engine — Execution Plan

**Project:** Cue (umbrella)
**Component:** `cue-alexa`
**Version:** 0.1 (Draft)
**Date:** 8 June 2026
**Author:** Gokul
**Related:** `CUE_ALEXA_BRD.md`, `CUE_README.md`

---

## 1. Architecture overview

```
┌───────────────────────────────────────────────────────────┐
│  User shell                                                │
│  $ cue "turn on the lights"          ← umbrella (typical)  │
│  $ cue-alexa "turn on the lights"    ← direct (advanced)   │
└──────────────────────────┬────────────────────────────────┘
                           │
                ┌──────────▼────────────┐
                │  bin/cue               │   Umbrella router
                │  (separate repo)       │   (auto-routes by config)
                └──────────┬─────────────┘
                           │
                ┌──────────▼────────────┐
                │  bin/cue-alexa         │   Engine binary
                │  (bash front-end)      │   - flag parsing
                │                        │   - config loading
                │                        │   - JSON / quiet modes
                └──────────┬─────────────┘
                           │
                ┌──────────▼─────────────┐
                │  lib/dispatcher.sh     │   Mode router
                │                        │   text / speak / routine
                └──────────┬─────────────┘
                           │
                ┌──────────▼─────────────┐
                │  vendor/alexa-remote-  │   Vendored upstream
                │     control.sh         │   (pinned version)
                └──────────┬─────────────┘
                           │
                ┌──────────▼─────────────┐
                │  ~/.config/cue/        │   Shared config root
                │   config.toml          │   (default vendor, etc.)
                │   alexa/               │   Alexa engine state:
                │     config.toml        │   - engine-specific opts
                │     cookie.txt         │   - session cookie
                │     devices.cache.json │   - device cache
                └──────────┬─────────────┘
                           │
                           ▼
                 alexa.amazon.* (unofficial)
                           │
                           ▼
                     Echo devices
```

**Layering rule:** the engine binary (`bin/cue-alexa`) must remain stable even when the vendored upstream changes its internal flags. All upstream-coupling lives in `lib/dispatcher.sh`. The umbrella `cue` lives in its own repo and shells out to engines via PATH — engines must work whether `cue` is installed or not.

---

## 2. Tech stack

| Layer            | Choice                                        | Why |
|------------------|-----------------------------------------------|-----|
| Front-end CLI    | Bash 4+ / Zsh-compatible                      | Same env as upstream, no runtime install |
| Argument parsing | Hand-rolled `getopts` + long-flag shim        | No external deps |
| Config format    | TOML via `yj` or inline parser                | Human-editable, stable schema |
| JSON output      | `jq` for emission, `jq` for parsing upstream  | Already required by upstream |
| Auth backend     | `oath-toolkit` (`oathtool`) for TOTP          | Already required by upstream |
| Upstream         | `alexa-remote-control` (vendored, pinned)     | Battle-tested reverse engineering |
| Tests            | `bats-core` + curl mocks                      | Bash-native test framework |
| Packaging        | Homebrew tap + curl `install.sh` for Linux    | Familiar install patterns |
| CI               | GitHub Actions                                | Free, matrix testing |

---

## 3. Repository structure

```
cue-alexa/
├── bin/
│   └── cue-alexa                  # Stable user-facing CLI
├── lib/
│   ├── dispatcher.sh              # Routes mode → upstream
│   ├── config.sh                  # Config load / write
│   ├── auth.sh                    # Login, cookie capture, refresh
│   ├── output.sh                  # JSON / human / quiet formatters
│   └── errors.sh                  # Exit code constants + messages
├── vendor/
│   └── alexa_remote_control.sh    # Pinned upstream
├── share/
│   └── completions/
│       ├── _cue-alexa             # Zsh completion
│       └── cue-alexa.bash         # Bash completion
├── tests/
│   ├── unit/
│   │   ├── dispatcher.bats
│   │   ├── config.bats
│   │   └── output.bats
│   ├── integration/
│   │   └── doctor.bats            # Hits real account in CI-opt-in mode
│   └── fixtures/
│       └── mock-amazon/
├── docs/
│   ├── INSTALL.md
│   ├── AUTH_RUNBOOK.md            # "What to do when login breaks"
│   ├── COMMANDS.md
│   └── HOMEASSISTANT.md
├── install.sh                     # Curl-pipe installer for Linux
├── Formula/cue-alexa.rb           # Homebrew formula
├── CLAUDE.md                      # Agent context (project-level)
├── AGENT_RULES.md                 # Multi-agent rules (mirrors DiskScout pattern)
├── CUE_ALEXA_BRD.md
├── CUE_ALEXA_EXECUTION_PLAN.md
└── README.md
```

---

## 4. Phased roadmap

### Phase 0 — Foundations (3–5 hours)
*Goal: skeleton repo, vendored upstream, "hello world" command runs end-to-end.*

| Task | Estimate | Deliverable |
|------|----------|-------------|
| Initialise repo, license, README skeleton | 30m | Empty repo, GPL-2.0 / MIT |
| Author `CLAUDE.md` + `AGENT_RULES.md` | 45m | Agent context committed |
| Vendor `alexa_remote_control.sh` at pinned commit | 30m | `vendor/` + LICENSE notes |
| `bin/cue-alexa --help` skeleton (no-op) | 1h | Help text + exit codes |
| Wire `cue-alexa --version` reading from a file | 30m | Versioning baseline |
| Smoke-test: manual cookie + `cue-alexa "hi"` runs against real account | 1h | Confirmation that vendored upstream works |

**Exit criteria:** `cue-alexa "test"` sends a real command to a real Echo after manual cookie setup.

---

### Phase 1 — MVP (8–12 hours)
*Goal: usable on the author's own setup, covering FR-001 to FR-024.*

| Task | Estimate | Requirements |
|------|----------|--------------|
| `lib/config.sh` — TOML read/write | 1h | FR-030 |
| `lib/auth.sh` — credential mode | 1.5h | FR-001 |
| `lib/auth.sh` — cookie capture mode | 1h | FR-002 |
| `lib/dispatcher.sh` — text / speak / routine routing | 1.5h | FR-010, FR-011, FR-012, FR-013 |
| `bin/cue-alexa` — `--device`, `--mode`, `--all` flags | 1h | FR-014, FR-015 |
| `bin/cue-alexa devices` / `groups` / `routines` | 1.5h | FR-020, FR-021, FR-022 |
| `bin/cue-alexa doctor` | 1h | FR-023 |
| `lib/output.sh` — `--json`, `--quiet`, `--verbose` | 1h | FR-024, FR-041–FR-043 |
| `lib/errors.sh` — documented exit codes | 30m | FR-040, FR-044 |
| Manual end-to-end test against author's Echo fleet | 1h | — |

**Exit criteria:**
- Author can install fresh on a clean Mac in < 10 minutes
- `cue-alexa doctor` passes
- Text, speak, and routine modes all verified against real devices

---

### Phase 2 — Hardening (6–9 hours)
*Goal: ready for power-user adoption beyond the author.*

| Task | Estimate | Requirements |
|------|----------|--------------|
| Homebrew formula + tap setup | 1.5h | FR-050 |
| Linux `install.sh` (curl-pipe) | 1h | FR-051 |
| Self-update check on `doctor` | 1h | FR-052 |
| `bats-core` unit test suite | 2h | — |
| GitHub Actions CI (macOS + Ubuntu matrix) | 1.5h | — |
| Bash + Zsh shell completions | 1h | UX polish |
| `docs/AUTH_RUNBOOK.md` for breakage scenarios | 1h | NFR-007 |

**Exit criteria:** Anyone with the install command can be making `cue-alexa` calls in < 10 minutes on macOS or Linux.

---

### Phase 3 — Integrations (4–6 hours)
*Goal: composable with the rest of the user's home stack.*

| Task | Estimate | Notes |
|------|----------|-------|
| Home Assistant `shell_command` recipes | 1h | `docs/HOMEASSISTANT.md` |
| Raycast script command bundle | 1h | macOS power user UX |
| Verify standalone + umbrella compat (`cue-alexa` and `cue → cue-alexa`) | 1h | Engine works with or without umbrella |
| Cron / launchd example: nightly announcements | 30m | Example recipes |
| BetterTouchTool / Stream Deck examples | 30m | Power-user UX |

**Exit criteria:** Documented recipes for every integration the author uses personally.

---

### Phase 4 — Stretch (timeboxed, optional)
*Goal: nice-to-haves that don't gate v1 release.*

- Menu bar app (Swift / SwiftUI) — read-only status + quick commands
- Voice input from terminal mic (off-by-default)
- Profile / multi-account support
- Web UI for routine browsing
- Push notification bridge back from Alexa Notifications API

---

## 5. Milestone roadmap

| Milestone | Target date    | Definition of done |
|-----------|----------------|--------------------|
| M0 — Skeleton runs | Week 1 | Phase 0 complete; manual smoke test passes |
| M1 — MVP usable    | Week 2 | Phase 1 complete; author uses daily for 5 days |
| M2 — Public-ready  | Week 4 | Phase 2 complete; tagged v0.1.0 on Homebrew |
| M3 — Integrated    | Week 5 | Phase 3 complete; Home Assistant + Raycast wired |
| M4 — v1.0          | Week 8 | Two weeks of stability; documentation polished |

(Calendar dates are illustrative; this is a no-hard-deadline indie project. Treat as relative ordering.)

---

## 6. Test and validation plan

| Layer | Coverage |
|-------|----------|
| Unit  | `lib/*.sh` — config parsing, mode dispatch, output formatting, error mapping |
| Integration | `doctor`, `devices`, `groups`, `routines` against a sandbox Amazon account (CI secret) |
| Manual | Real-device verification on the author's Echo fleet before each tagged release |
| Regression | Snapshot the upstream's known-good commit; CI alerts on upstream HEAD divergence |

**Acceptance gates per release:**
1. All `bats` tests pass on macOS + Ubuntu
2. `cue-alexa doctor` succeeds on the author's setup
3. `cue-alexa "test"` round-trips successfully on the author's setup
4. Documentation rebuilt and reviewed

---

## 7. Risk register (engineering view)

| Risk | Owner | Mitigation |
|------|-------|------------|
| Upstream breaks between MVP and Phase 2 | Solo | Pin known-good commit; vendor it |
| Author's Amazon account flagged | Solo | Conservative rate limits; no retries on auth fail |
| Cookie format changes (India region) | Solo | Cookie-capture fallback documented |
| Homebrew formula approval lag | Solo | Self-hosted tap as alternative |
| Bash version skew (macOS Bash 3.2 default) | Solo | Document `brew install bash`; shebang to `#!/usr/bin/env bash` and feature-gate |

---

## 8. Execution prompts (Claude Code / agent-ready)

These prompts are written to be pasted directly into Claude Code or a similar agent session. Each assumes `CLAUDE.md` + `AGENT_RULES.md` are present at the repo root. Run them in order — each builds on the previous.

> **Convention:** every prompt ends with an explicit acceptance check the agent must run before declaring done.

---

### EP-1 — Bootstrap the repo

```
You are setting up a new bash CLI project called `cue-alexa` from the BRD
and execution plan in CUE_ALEXA_BRD.md and CUE_ALEXA_EXECUTION_PLAN.md.

Tasks:
1. Read CUE_ALEXA_BRD.md and CUE_ALEXA_EXECUTION_PLAN.md fully before
   making any changes.
2. Create the directory structure exactly as specified in section 3 of
   the execution plan ("Repository structure"), but do not yet implement
   any logic — only create files with a single-line comment explaining
   each file's intended purpose.
3. Add a minimal README.md with the project name, one-paragraph summary,
   install placeholder, and a link to the BRD.
4. Add MIT LICENSE.
5. Initialise git and make one commit titled
   "chore: bootstrap repo skeleton from BRD v0.1".

Acceptance:
- `tree -L 3` matches section 3 of the execution plan
- `git log --oneline` shows exactly one commit
- No file contains executable logic yet — only placeholder comments
```

---

### EP-2 — Vendor the upstream

```
You are vendoring the `alexa-remote-control` script into this repo.

Tasks:
1. Download
   https://raw.githubusercontent.com/thorsten-gehrig/alexa-remote-control/master/alexa_remote_control.sh
   into vendor/alexa_remote_control.sh
2. Record the upstream commit SHA in vendor/UPSTREAM.md along with the
   download date, the upstream URL, license info, and a one-paragraph
   summary of why it is vendored (see BRD section 10, "Risks").
3. Do NOT modify the upstream script. If patches are needed later they
   will live as separate `.patch` files in vendor/patches/.
4. Add vendor/ to a top-level VENDORING.md explaining the policy
   (pinned, audit periodically, never edit in place).
5. Make a commit titled
   "feat(vendor): pin alexa-remote-control upstream".

Acceptance:
- vendor/alexa_remote_control.sh exists and is executable
- vendor/UPSTREAM.md contains a real SHA (not a placeholder)
- The vendored script has not been edited (verify via diff against the
  raw URL)
```

---

### EP-3 — Implement the CLI front-end skeleton

```
You are implementing bin/cue-alexa as described in section 3 of
CUE_ALEXA_EXECUTION_PLAN.md and FR-040–FR-044 of the BRD.

Tasks:
1. Implement bin/cue-alexa in bash with `set -euo pipefail` at the top.
2. Support these flags at the top level (no behaviour yet — just parse
   and echo what was parsed when --verbose is set):
   --device <name>, --all, --group <name>, --mode {text|speak|routine},
   --json, --quiet, --verbose, --help, --version
3. Support these subcommands as stubs that print "not yet implemented"
   and exit 99:
   doctor, devices, groups, routines, login, config
4. Wire --version to read from a file VERSION at the repo root
   (write "0.0.1" to it).
5. Wire --help to print a clear, sectioned help text covering all
   commands and flags.
6. Implement lib/errors.sh with constants for every exit code in
   FR-040 / FR-044 and a function `die <code> <message>`.

Acceptance:
- `bin/cue-alexa --help` prints help text
- `bin/cue-alexa --version` prints "0.0.1"
- `bin/cue-alexa doctor` prints "not yet implemented" and exits 99
- `bin/cue-alexa --invalid-flag` exits with a documented non-zero code
- `shellcheck bin/cue-alexa lib/*.sh` passes with no warnings
```

---

### EP-4 — Config and auth

```
You are implementing config and auth as per BRD section 7.1 (FR-001 to
FR-007) and section 7.4 (FR-030 to FR-033).

Tasks:
1. Implement lib/config.sh:
   - Read ~/.config/cue/alexa/config.toml
   - Provide `config_get <key>` and `config_set <key> <value>`
   - Honour the precedence: CLI flag > env var > config file
2. Implement lib/auth.sh:
   - `auth_login_credentials` — interactively prompts for email,
     password, TOTP secret; writes them ONLY to the config dir with
     mode 0600
   - `auth_login_cookie` — prompts for path to a Netscape cookie file
     and copies it to the config dir
   - `auth_status` — returns 0 if cookie exists and looks valid,
     non-zero otherwise; emits time-to-expiry on stderr if --verbose
3. Wire `cue-alexa login` to offer both flows interactively.
4. Wire `cue-alexa config get/set` to lib/config.sh.

Acceptance:
- `cue-alexa login` walks through credential flow on a clean system
- `cue-alexa config set default_device "Living Room"` persists
- `cue-alexa config get default_device` returns "Living Room"
- File permissions on ~/.config/cue/alexa/ are 0700; secret files 0600
- shellcheck still passes
```

---

### EP-5 — Dispatcher and command modes

```
You are implementing the dispatcher and the three command modes per
BRD FR-010 to FR-018.

Tasks:
1. Implement lib/dispatcher.sh with one entry point:
   `dispatch <mode> <device-spec> <text>`
   where mode ∈ {text, speak, routine} and device-spec is one of
   `--device <name>`, `--all`, `--group <name>`.
2. The dispatcher calls vendor/alexa_remote_control.sh with the
   appropriate `-e textcommand:`, `-e speak:`, or `-e automation:`
   directive and the appropriate device flag.
3. ALL user input passed to the upstream MUST be properly quoted to
   prevent shell injection. Add a test for this.
4. Wire `bin/cue-alexa <text>` (no subcommand) to dispatch with the
   resolved default mode and device.
5. Handle these failure modes explicitly with the correct exit code
   from lib/errors.sh: auth expired (10), device not found (20),
   upstream call failed (30), network error (40).

Acceptance:
- `cue-alexa "test"` round-trips on the author's setup
- `cue-alexa --mode speak "hello"` makes the Echo say "hello" in TTS
- `cue-alexa --mode routine "Morning"` triggers the routine
- A malicious-looking string like `"; rm -rf / ;"` is passed safely
  (caught by a bats test)
- shellcheck passes; bats tests pass
```

---

### EP-6 — Discovery and doctor

```
You are implementing the introspection commands per BRD FR-020 to
FR-024.

Tasks:
1. Implement `cue-alexa devices` — calls the upstream `-a` and parses
   the output into a stable table (name, serial, type, online).
2. Implement `cue-alexa groups` and `cue-alexa routines` similarly.
3. Implement `cue-alexa doctor` reporting: auth status, time-to-expiry,
   device count, region, last successful call timestamp (read from a
   cache file).
4. All four commands MUST support `--json` for machine-readable output.
5. Cache device / group / routine lists in
   ~/.config/cue/alexa/cache.json with a 24h TTL; `doctor --refresh`
   forces a refresh.

Acceptance:
- `cue-alexa devices` prints a clean table on the author's setup
- `cue-alexa devices --json` produces valid JSON parseable by `jq`
- `cue-alexa doctor` reports green on a healthy setup and red with a
  clear remediation message on an unhealthy one
- Cache survives a CLI restart; `--refresh` invalidates it
```

---

### EP-7 — Packaging and CI

```
You are packaging the project per BRD FR-050 to FR-053.

Tasks:
1. Write a Homebrew formula in Formula/cue-alexa.rb. Test it via
   `brew install --build-from-source ./Formula/cue-alexa.rb`.
2. Write an install.sh for Linux that:
   - Downloads the latest tagged release
   - Verifies a SHA256 checksum
   - Installs to /usr/local/bin (no sudo for $HOME/.local/bin fallback)
   - Runs `cue-alexa doctor` to confirm install
3. Set up GitHub Actions in .github/workflows/ci.yml that runs:
   - shellcheck on all bash files
   - bats unit tests
   - Both on macos-latest and ubuntu-latest
4. Tag the release as v0.1.0 once CI is green.

Acceptance:
- `brew install ./Formula/cue-alexa.rb` succeeds on a clean Mac
- `curl -fsSL https://.../install.sh | bash` succeeds on a clean Ubuntu
- CI passes on both runners
- A v0.1.0 git tag exists
```

---

### EP-8 — Integrations and recipes

```
You are wiring the CLI into the rest of the home stack per execution
plan Phase 3.

Tasks:
1. Write docs/HOMEASSISTANT.md with copy-pasteable
   `shell_command:` configuration.yaml entries for:
   - Announcing on a chosen Echo when a door opens
   - Triggering an Alexa routine from an HA automation
   - Multi-vendor fan-out using the unified `cue` umbrella
2. Write a Raycast script command in
   docs/raycast/cue-alexa.sh with proper Raycast metadata headers.
3. The unified `cue` umbrella lives in its own separate repo and is
   out of scope for this engine. Add docs/UMBRELLA.md noting that
   the umbrella `cue` discovers `cue-alexa` via PATH and that this
   engine MUST work standalone whether or not `cue` is installed.
4. Write docs/recipes/cron-examples.md with 3 working cron lines
   (laundry done, garage door check, nightly snapshot).

Acceptance:
- All recipe files are runnable as-is on the author's setup
- HA YAML validates against a real HA installation
- Raycast bundle imports cleanly into Raycast
```

---

## 9. Open questions

1. Region default — author primarily uses `.in`; should the installer auto-detect via IP geolocation, or always prompt?
2. Should the dispatcher abstract away the underlying upstream entirely so that swapping to `alexa-remote2` (Node.js) is a one-line change?
3. Should the Homebrew formula bundle `oath-toolkit` and `jq` as dependencies, or document them as prerequisites?
4. Telemetry — even opt-in? BRD says no telemetry without opt-in; should opt-in even be offered? (Lean: no.)
5. Account profile system — needed for v1 or strictly Phase 4?

---

## 10. Appendix — exit code table

| Code | Meaning |
|------|---------|
| 0    | Success |
| 1    | Generic failure |
| 2    | Invalid usage (bad flags, missing args) |
| 10   | Auth expired or missing |
| 11   | Auth refresh failed |
| 20   | Device not found |
| 21   | Device offline |
| 30   | Upstream call returned an error |
| 31   | Upstream returned unparseable response |
| 40   | Network error |
| 41   | Amazon rate-limit (429) |
| 99   | Not yet implemented (development only) |

---

*End of Execution Plan v0.1*
