# Cue — Alexa Engine — Business Requirements Document

**Project:** Cue (umbrella) — text-to-voice-assistant CLI
**Component:** `cue-alexa` (Alexa engine binary)
**Version:** 0.1 (Draft)
**Date:** 8 June 2026
**Author:** Gokul
**Status:** Draft — pending technical validation

---

## 1. Document control

| Version | Date       | Author | Changes        |
|---------|------------|--------|----------------|
| 0.1     | 2026-06-08 | Gokul  | Initial draft  |

**Related documents**
- `CUE_README.md` — umbrella project overview, cross-vendor `cue` router
- `CUE_ALEXA_EXECUTION_PLAN.md` — phased build plan + execution prompts for this engine
- `CUE_GOOGLE_BRD.md` — sibling engine under the same Cue umbrella
- `CLAUDE.md` (to be authored) — agent context file for Claude Code orchestration

---

## 2. Executive summary

`cue-alexa` is the Alexa engine binary of the **Cue** project — a POSIX command-line tool that lets a power user pipe plain-text commands from a terminal into Amazon Echo / Alexa devices on their personal account. It exposes the same `textcommand:` (text-as-spoken NLU interpretation), `speak:` (TTS playback), and `automation:` (named routine trigger) primitives used internally by the Alexa mobile app.

Under the Cue umbrella, the user normally types `cue "turn on the lights"` — the umbrella router auto-selects this engine or its Google sibling. `cue-alexa` can also be invoked directly when the user wants to bypass routing or use Alexa-specific subcommands (`cue-alexa devices`, `cue-alexa routines`).

The engine is built as a thin, auditable bash wrapper over the community-maintained `alexa-remote-control` project, with a stable interface so the upstream's instability (auth flow changes, cookie format rotations) is contained behind a single integration layer.

Intended use: personal automation, home-assistant glue, cron-driven announcements, multi-ecosystem fan-out alongside the sibling Google engine. **Not** for commercial distribution.

---

## 3. Problem statement

Amazon Alexa exposes no first-party API for arbitrary text → device-execution flows on a personal account. The official developer surfaces solve adjacent problems:

- **Alexa Voice Service (AVS)** is for building Alexa-enabled hardware
- **Alexa Skills Kit (ASK)** requires an invocation phrase, custom slots, certification, and is not a general-purpose remote
- **Smart Home API** requires being a device manufacturer with an OAuth integration

Power users with Echo devices in their homes are left with three poor options:
- Speak aloud — impossible for scripts, schedulers, headless servers
- Build a custom skill — heavyweight, invocation phrase friction, latency, certification
- Use IFTTT / SmartThings as middleware — brittle, monthly cost, additional cloud dependency

The community has solved this with `alexa-remote-control`, but the project is a single 1,500-line bash file with frequent breakage cycles and a non-obvious cookie capture flow. The current product wraps that complexity in a stable, documented, scriptable interface.

---

## 4. Goals and non-goals

### 4.1 Goals
| ID | Goal |
|----|------|
| G1 | Engine binary (`cue-alexa "<text>"`) executes a command on a configured Echo; also callable via the umbrella `cue "<text>"` |
| G2 | Support `textcommand:` (NLU interpretation), `speak:` (TTS), `automation:` (routine trigger) |
| G3 | Target a specific device by friendly name (`--device "Living Room"`) |
| G4 | Multi-device broadcast (`--all`, `--group "Downstairs"`) |
| G5 | Resilience against upstream auth changes via dual-mode auth (credentials + cookie capture) |
| G6 | macOS + Linux installable in <10 minutes with documented setup |
| G7 | Composable from Home Assistant `shell_command`, cron, Raycast, shell scripts |
| G8 | Stable user-facing CLI flags even when upstream changes underneath |
| G9 | Diagnostic command (`cue-alexa doctor`) that validates auth and device discovery |
| G10 | Non-zero exit codes and machine-parseable JSON output mode (`--json`) |

### 4.2 Non-goals
| ID  | Non-goal |
|-----|----------|
| NG1 | Commercial distribution (Amazon TOS risk) |
| NG2 | Building a custom Alexa skill |
| NG3 | Replacing AVS for device manufacturers |
| NG4 | Two-way continuous conversation / dialog state |
| NG5 | Local-only / offline execution (requires Amazon cloud) |
| NG6 | Native Windows support (WSL is acceptable) |
| NG7 | GUI / menu bar app (separate side-project if pursued) |
| NG8 | Multi-user / multi-account management in one install |

---

## 5. Target users and personas

### Persona 1 — The home-automation power user (primary)
Owns 2–6 Echo devices, runs Home Assistant on a local server, already comfortable in bash/zsh. Wants to fire Alexa routines from HA automations and announce events through Echo speakers without paying for IFTTT.

### Persona 2 — The indie developer / tinkerer (secondary)
Wants Alexa control from scripts, custom tooling, Raycast scripts, BetterTouchTool gestures, or status-bar utilities. Cares about reproducibility, JSON output, and being able to read the source.

### Persona 3 — The headless-server operator (tertiary)
Runs scheduled tasks on a NAS or Raspberry Pi. Wants nightly announcements (laundry done, garage left open, sprinkler started), driven by cron.

---

## 6. Use cases / user journeys

### UC-01 — First-run setup
1. User runs `brew install` / `curl install` command
2. Tool prompts for Amazon region (`amazon.com`, `amazon.in`, `amazon.de`, etc.)
3. Tool offers two auth flows:
   - **Credentials + TOTP** — user enters email, password, 2FA secret
   - **Cookie capture** — user pastes Netscape-format cookie from browser DevTools
4. Tool calls `cue-alexa doctor` automatically — validates auth, lists devices, prints results
5. User can now run `cue-alexa "turn on the lights"`

### UC-02 — Text command to default device
- `cue-alexa "turn on the kitchen lights"` → uses `$ALEXA_DEFAULT_DEVICE` env var or config file
- Echo interprets text as if spoken, executes the command, returns success exit code

### UC-03 — Device-targeted command
- `cue-alexa --device "Bedroom" "set a timer for 10 minutes"` → routes to specified device

### UC-04 — Multi-device broadcast
- `cue-alexa --all "dinner is ready"` → broadcasts as TTS announcement to every Echo
- `cue-alexa --group "Downstairs" "we're leaving"` → broadcasts to a device group

### UC-05 — Named routine trigger
- `cue-alexa --routine "Morning Routine"` → triggers a routine defined in the Alexa app

### UC-06 — Pipeline integration (Home Assistant)
- HA `shell_command` integration calls `cue-alexa --device "Garage" "the garage door is open"`
- Exit code is checked; HA logs failures

### UC-07 — Diagnostic / health check
- `cue-alexa doctor` reports: cookie validity, time-to-expiry, device count, region, last successful call

### UC-08 — Cookie / auth renewal
- When auth expires, next call fails fast with a clear "run `cue-alexa login` to renew" message
- `cue-alexa login` re-runs the chosen auth flow

---

## 7. Functional requirements

### 7.1 Authentication and session
| ID     | Requirement |
|--------|-------------|
| FR-001 | Tool MUST support credential-based auth (email, password, TOTP secret) via interactive prompt |
| FR-002 | Tool MUST support Netscape-format cookie file import for environments where credential login fails |
| FR-003 | Cookie / session state MUST be stored in `~/.config/cue/alexa/` with mode `0600` |
| FR-004 | Tool MUST support all major Amazon regions (`.com`, `.co.uk`, `.de`, `.in`, `.com.au`, `.co.jp`, `.fr`, `.it`, `.es`, `.com.br`) via region config |
| FR-005 | Tool MUST automatically refresh the session cookie when nearing expiry (best-effort) |
| FR-006 | Tool MUST detect expired auth and exit with a documented exit code (`exit 10`) and human message |
| FR-007 | `cue-alexa login` MUST be idempotent and re-runnable to refresh credentials |

### 7.2 Command execution
| ID     | Requirement |
|--------|-------------|
| FR-010 | Tool MUST support `textcommand:` mode — send a string for Alexa NLU interpretation |
| FR-011 | Tool MUST support `speak:` mode — send a string for Echo TTS playback (no interpretation) |
| FR-012 | Tool MUST support `automation:` mode — trigger a named routine defined in the Alexa app |
| FR-013 | Tool MUST support `--mode {text\|speak\|routine}` to choose explicitly; default is `text` |
| FR-014 | Tool MUST support `--device "<name>"` to target a single Echo by its app-friendly name |
| FR-015 | Tool MUST support `--all` to broadcast to every Echo on the account |
| FR-016 | Tool MUST support `--group "<group-name>"` to target a device group |
| FR-017 | Tool MUST escape user input safely (no shell injection via the command text) |
| FR-018 | Tool MUST handle Unicode (em-dashes, smart quotes, non-Latin scripts) in the command string |

### 7.3 Discovery and introspection
| ID     | Requirement |
|--------|-------------|
| FR-020 | `cue-alexa devices` MUST list all devices with name, serial, type, online status |
| FR-021 | `cue-alexa groups` MUST list device groups |
| FR-022 | `cue-alexa routines` MUST list available routines by name and ID |
| FR-023 | `cue-alexa doctor` MUST report auth status, time-to-expiry, device count, region, last call timestamp |
| FR-024 | All discovery commands MUST support `--json` for machine-readable output |

### 7.4 Configuration
| ID     | Requirement |
|--------|-------------|
| FR-030 | Tool MUST read config from `~/.config/cue/alexa/config.toml` |
| FR-031 | Tool MUST allow override via environment variables (`ALEXA_DEFAULT_DEVICE`, `ALEXA_REGION`, etc.) |
| FR-032 | Tool MUST allow override via CLI flags (highest precedence: flag > env > config) |
| FR-033 | `cue-alexa config get/set` MUST allow non-interactive config manipulation |

### 7.5 Output and errors
| ID     | Requirement |
|--------|-------------|
| FR-040 | Tool MUST return exit code `0` on success, non-zero on failure, with documented code mapping |
| FR-041 | Tool MUST support `--json` for machine-readable output of all commands |
| FR-042 | Tool MUST support `--quiet` to suppress non-error stdout |
| FR-043 | Tool MUST support `--verbose` / `-v` for debug logging |
| FR-044 | Errors MUST clearly distinguish: auth failure, network failure, device-not-found, upstream API change |

### 7.6 Installation and updates
| ID     | Requirement |
|--------|-------------|
| FR-050 | Tool MUST be installable via Homebrew tap on macOS |
| FR-051 | Tool MUST be installable via single curl `install.sh` on Linux |
| FR-052 | Tool MUST self-check for updates and prompt (opt-out) on `doctor` runs |
| FR-053 | Tool MUST bundle / vendor a known-good version of `alexa-remote-control.sh` |

---

## 8. Non-functional requirements

| ID      | Requirement |
|---------|-------------|
| NFR-001 | Single text command round-trip MUST complete in < 4 seconds under normal network conditions |
| NFR-002 | Tool MUST work fully offline for `--help`, `config`, and any commands not requiring Amazon API |
| NFR-003 | No telemetry of any kind without explicit opt-in |
| NFR-004 | All secrets (cookies, passwords, TOTP seeds) MUST be stored only locally, never transmitted to any third party |
| NFR-005 | Source MUST remain auditable: ≤ 2000 lines of bash + ≤ 1 dependency on the upstream script |
| NFR-006 | Tool MUST not require sudo / root at any point |
| NFR-007 | Documentation MUST include a "what to do when Amazon breaks auth" runbook |
| NFR-008 | Tool MUST degrade gracefully — partial functionality if some commands break upstream |

---

## 9. Constraints and assumptions

### Constraints
- Amazon does not publish or support this API surface — every release is one Amazon-side change away from breakage
- Cookie / TOTP-based login is rate-limited; aggressive retries trigger account lockouts
- Some regions (notably `amazon.in`) have stricter login flows and may require cookie-capture only
- `textcommand:` only works on devices with a microphone (Echoes — not Fire TVs in most regions)

### Assumptions
- User owns and controls the Amazon account being automated
- User has at least one Echo device set up and online
- User is technical enough to handle cookie capture if credential login breaks
- Amazon will not actively block this script as long as call volume is reasonable

---

## 10. Risks and mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Amazon changes login flow, breaks credential auth | High | High | Cookie-capture fallback always supported; clear runbook |
| Amazon changes cookie format / endpoints | Medium | High | Pin known-good upstream version; track upstream PRs |
| Amazon detects scripted traffic and rate-limits / bans account | Low–Medium | High | Conservative defaults, no retries on auth failure, respect 429s |
| Upstream `alexa-remote-control` becomes unmaintained | Medium | Medium | Vendored copy + ability to swap to Node-based fork (`alexa-remote2`) |
| User's region not supported by upstream | Medium | Low | Document supported regions; user can patch upstream and contribute back |
| User mistypes a device name and broadcasts to wrong device | Medium | Low | `--device` requires exact match; `--all` requires confirmation in interactive mode |

---

## 11. Out of scope (v1)

- GUI / menu bar app
- Native Windows support (PowerShell port)
- Voice input from terminal mic
- Wake-word detection
- Multi-account / account switching beyond a `--profile` flag
- Push notifications back from Echo to terminal
- Recording / playback of audio from Echo devices

---

## 12. Success metrics

| ID  | Metric | Target |
|-----|--------|--------|
| SM-1 | Setup time (install → first successful command) | < 10 minutes |
| SM-2 | Command round-trip latency (p50) | < 3 seconds |
| SM-3 | Days between Amazon-side breakages | > 60 days (aspirational) |
| SM-4 | Time to recover from breakage (patch released) | < 7 days |
| SM-5 | Personal usage frequency | > 10 commands / day |

---

## 13. Glossary

| Term | Definition |
|------|------------|
| **AVS** | Alexa Voice Service — Amazon's official API for *being* an Alexa device |
| **ASK** | Alexa Skills Kit — Amazon's official API for *building skills* invoked by users |
| **`textcommand:`** | Directive that sends a text string through Alexa's NLU pipeline as if spoken |
| **`speak:`** | Directive that plays a string as TTS without NLU interpretation |
| **`automation:`** | Directive that triggers a named routine defined in the Alexa app |
| **Routine** | A multi-step automation defined in the Alexa app (e.g., "Morning Routine") |
| **Echo** | Any Alexa-enabled Amazon device with a microphone |
| **Cookie capture** | Manual auth flow where the user copies their browser session cookie into the CLI's storage |
| **TOTP** | Time-based one-time password — the 2FA mechanism Amazon supports |

---

*End of BRD v0.1*
