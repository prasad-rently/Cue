# Cue — Google Engine — Business Requirements Document

**Project:** Cue (umbrella) — text-to-voice-assistant CLI
**Component:** `cue-google` (Google Assistant engine binary)
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
- `CUE_GOOGLE_EXECUTION_PLAN.md` — phased build plan + execution prompts for this engine
- `CUE_ALEXA_BRD.md` — sibling engine under the same Cue umbrella
- `CLAUDE.md` (to be authored) — agent context file for Claude Code orchestration

---

## 2. Executive summary

`cue-google` is the Google Assistant engine binary of the **Cue** project — a POSIX command-line tool that lets a power user send plain-text commands from a terminal to their personal Google Assistant account, executing them against their Google Home / Nest device graph. It wraps Google's official `embeddedassistant.googleapis.com` gRPC API via the Google Assistant SDK (Python), exposing a stable bash interface that mirrors its Alexa sibling.

Under the Cue umbrella, the user normally types `cue "turn on the lights"` — the umbrella router auto-selects this engine or its Alexa sibling. `cue-google` can also be invoked directly for Google-specific subcommands (`cue-google setup`, `cue-google device-model register`, etc.).

Unlike the Alexa engine, this one uses an **officially supported (though deprecated for new projects) API surface** with proper OAuth 2.0 — so it is more durable, but subject to Google's pace of deprecation.

Intended use: personal automation, home-assistant glue, cron-driven announcements, multi-ecosystem fan-out alongside the sibling Alexa engine. **Not** for commercial distribution.

---

## 3. Problem statement

Power users with Google Home / Nest devices need a way to send text commands from scripts, schedulers, and other tooling. Google offers three relevant APIs:

- **Google Assistant SDK** — sends text or audio queries through the full Assistant pipeline. Officially documented, OAuth-based, supports `--text-query` out of the box. **Deprecated for new projects since mid-2023** but functional for existing OAuth client IDs.
- **Smart Home actions / Home Graph API** — intended for device manufacturers integrating with Google Home, not for end-user command routing.
- **Google Home API (newer)** — preview / partner program; not generally available for personal projects.

The Assistant SDK remains the only end-user-accessible path for "send arbitrary text and have it execute as if I said it." The challenge is that setup is genuinely painful: GCP project creation, OAuth consent screen configuration, scope wrangling, device model registration. A clean CLI absorbs that complexity once.

The community alternative (`assistant-relay`) is unmaintained and depends on the same SDK underneath.

---

## 4. Goals and non-goals

### 4.1 Goals
| ID  | Goal |
|-----|------|
| G1  | Engine binary (`cue-google "<text>"`) executes a command against Google Assistant; also callable via the umbrella `cue "<text>"` |
| G2  | Use the official Assistant SDK gRPC API, not reverse-engineered endpoints |
| G3  | Return the Assistant's text response back to stdout for downstream piping |
| G4  | Encapsulate the GCP / OAuth setup pain into a guided onboarding flow |
| G5  | Support multiple virtual device identities (`--device-id`) so commands can be attributed |
| G6  | macOS + Linux installable in < 15 minutes (longer than Alexa because of GCP setup) |
| G7  | Composable from Home Assistant `shell_command`, cron, Raycast, shell scripts |
| G8  | Stable user-facing CLI flags even if Google deprecates further or migrates the underlying API |
| G9  | Diagnostic command (`cue-google doctor`) that validates OAuth, API reachability, device model registration |
| G10 | Non-zero exit codes and machine-parseable JSON output mode (`--json`) |
| G11 | Provide a clean migration path if Google forces a move to the newer Home API |

### 4.2 Non-goals
| ID   | Non-goal |
|------|----------|
| NG1  | Commercial distribution |
| NG2  | Hot-word / wake-word detection |
| NG3  | Audio capture / playback (text-only on both ends) |
| NG4  | Replacing first-party Google Assistant SDK for device manufacturers |
| NG5  | Two-way continuous conversation / dialog state across calls |
| NG6  | Local / offline execution (requires Google cloud) |
| NG7  | Native Windows support (WSL is acceptable) |
| NG8  | Multi-account / account switching beyond a `--profile` flag |
| NG9  | Google Workspace / business account support (consumer accounts only) |

---

## 5. Target users and personas

### Persona 1 — The home-automation power user (primary)
Owns Google Home / Nest devices, runs Home Assistant locally, comfortable in bash/zsh + light Python. Wants to trigger Google Assistant from HA automations without depending on IFTTT or paid middleware. Already has a GCP account.

### Persona 2 — The indie developer / tinkerer (secondary)
Wants Google Assistant control from scripts, custom tooling, Raycast scripts, status-bar utilities. Values the official API status — willing to navigate GCP setup once for long-term stability.

### Persona 3 — The cross-ecosystem user (tertiary)
Has both Echo and Google Home devices and wants a unified `cue` command that fans out to whichever ecosystem owns the target device. Pairs this with the Alexa engine.

---

## 6. Use cases / user journeys

### UC-01 — First-run onboarding
1. User runs `cue-google setup`
2. Tool walks them through:
   - Confirming a Google Cloud project exists (or creating one via `gcloud`)
   - Enabling the Google Assistant API
   - Configuring OAuth consent screen (External / Testing, self as test user)
   - Creating a Desktop OAuth client and downloading the JSON
   - Pointing the CLI at that JSON
   - Running OAuth consent flow in browser
   - Registering a virtual device model + device instance
3. Tool runs `cue-google doctor` and prints results

### UC-02 — Text command, default device identity
- `cue-google "turn on the kitchen lights"` → executes against the user's Google Home graph
- Assistant's text response is printed to stdout

### UC-03 — Text command with specific device identity
- `cue-google --device-id "garage-pi" "open the garage"` → executes attributed to a different virtual device (useful for room-aware routing, "what's the temperature here?" answers depending on virtual device location)

### UC-04 — Capture Assistant response
- `result=$(cue-google --quiet "what's on my calendar tomorrow")` → captures the response text for downstream processing

### UC-05 — Pipeline integration (Home Assistant)
- HA `shell_command` calls `cue-google --device-id "office-pi" "broadcast: the meeting starts in 5 minutes"`
- Exit code is checked; HA logs failures

### UC-06 — Diagnostic / health check
- `cue-google doctor` reports: OAuth token validity, refresh capability, API reachability, registered devices, project ID, last successful call

### UC-07 — Token refresh and re-consent
- Token refresh is automatic. If refresh fails (revoked, password changed), `cue-google login` triggers a new consent flow.

### UC-08 — Cross-vendor fan-out
- Used together with `cue-alexa` under the unified `cue` umbrella

---

## 7. Functional requirements

### 7.1 Authentication and session
| ID     | Requirement |
|--------|-------------|
| FR-001 | Tool MUST use OAuth 2.0 with the `assistant-sdk-prototype` and `gcm` scopes |
| FR-002 | Tool MUST store OAuth credentials in `~/.config/cue/google/` with mode `0600` |
| FR-003 | Tool MUST handle token refresh automatically; fall back to interactive re-consent on refresh failure |
| FR-004 | `cue-google login` MUST be idempotent and re-runnable to refresh consent |
| FR-005 | Tool MUST support pointing at a user-provided client_secret JSON file |
| FR-006 | Tool MUST detect expired / revoked consent and exit with a documented exit code |
| FR-007 | `cue-google setup` MUST guide the user through GCP project setup with copy-pasteable `gcloud` commands |

### 7.2 Device model and identity
| ID     | Requirement |
|--------|-------------|
| FR-010 | Tool MUST allow registering a device model via `cue-google device-model register` |
| FR-011 | Tool MUST allow registering / listing / deleting device instances |
| FR-012 | Tool MUST support `--device-id <id>` to identify the calling virtual device |
| FR-013 | Tool MUST persist a default device-model-id and device-id in config |
| FR-014 | Device model registration MUST be runnable non-interactively for scripting |

### 7.3 Command execution
| ID     | Requirement |
|--------|-------------|
| FR-020 | Tool MUST support sending arbitrary text queries via the `text-query` interface |
| FR-021 | Tool MUST return the Assistant's textual response on stdout by default |
| FR-022 | Tool MUST support `--quiet` to suppress non-response stderr noise |
| FR-023 | Tool MUST escape user input safely (no shell injection via the query text) |
| FR-024 | Tool MUST handle Unicode (em-dashes, smart quotes, non-Latin scripts) |
| FR-025 | Tool MUST timeout gRPC calls after a configurable duration (default 15s) and exit cleanly |

### 7.4 Discovery and introspection
| ID     | Requirement |
|--------|-------------|
| FR-030 | `cue-google doctor` MUST report: OAuth status, API reachability, device model count, project ID |
| FR-031 | `cue-google device-model list` MUST list registered device models with IDs |
| FR-032 | `cue-google device list` MUST list registered device instances |
| FR-033 | All discovery commands MUST support `--json` for machine-readable output |

### 7.5 Configuration
| ID     | Requirement |
|--------|-------------|
| FR-040 | Tool MUST read config from `~/.config/cue/google/config.toml` |
| FR-041 | Tool MUST allow override via env vars (`GOOGLE_DEVICE_MODEL`, `GOOGLE_DEVICE_ID`, `GOOGLE_PROJECT_ID`) |
| FR-042 | Tool MUST allow override via CLI flags (precedence: flag > env > config) |
| FR-043 | `cue-google config get/set` MUST allow non-interactive config manipulation |

### 7.6 Output and errors
| ID     | Requirement |
|--------|-------------|
| FR-050 | Tool MUST return exit code 0 on success and a non-zero code on failure, with documented mapping |
| FR-051 | Tool MUST support `--json` to emit a structured response (query, text response, latency, request ID) |
| FR-052 | Tool MUST distinguish: auth failure, network failure, API quota / 429, device-model misconfig, unhandled query |
| FR-053 | Logs MUST never include OAuth tokens or refresh tokens |

### 7.7 Installation and updates
| ID     | Requirement |
|--------|-------------|
| FR-060 | Tool MUST be installable via Homebrew tap on macOS |
| FR-061 | Tool MUST be installable via single curl `install.sh` on Linux |
| FR-062 | Tool MUST manage its Python venv internally (user does not have to think about it) |
| FR-063 | Tool MUST pin its Python dependencies and surface deprecation warnings from upstream |

---

## 8. Non-functional requirements

| ID      | Requirement |
|---------|-------------|
| NFR-001 | Single text command round-trip MUST complete in < 4 seconds under normal network conditions |
| NFR-002 | `--help`, `config`, `doctor --offline` MUST work without network access |
| NFR-003 | No telemetry without explicit opt-in |
| NFR-004 | All OAuth state MUST be stored only locally, never transmitted to any third party other than Google |
| NFR-005 | Tool MUST not require sudo / root at any point |
| NFR-006 | Documentation MUST include a "what happens when Google deprecates the SDK" runbook |
| NFR-007 | Tool MUST gracefully handle Google's `UNAVAILABLE`, `DEADLINE_EXCEEDED`, and `PERMISSION_DENIED` gRPC errors |
| NFR-008 | Total wall-clock setup time (GCP + CLI) MUST be < 15 minutes for a user with a Google account |

---

## 9. Constraints and assumptions

### Constraints
- Google Assistant SDK is **deprecated for new projects** as of mid-2023; existing OAuth client IDs continue working
- Activity controls at `myactivity.google.com` (Web & App Activity, Device Information, Voice & Audio Activity) MUST be enabled or the API returns empty responses
- Smart-home commands route through the user's Google Home graph; only devices linked there are reachable
- The text-query interface does not support the "Hey Google, broadcast" semantics the same way voice does; broadcast support depends on device model + Home graph config

### Assumptions
- User has a personal Google account (not Workspace-managed)
- User has at least one Google Home / Nest device set up
- User can navigate the GCP console once during setup
- Google will continue running the Assistant SDK for existing clients during v1 lifetime

---

## 10. Risks and mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Google sunsets the Assistant SDK entirely | Medium (multi-year horizon) | Catastrophic | Architecture allows swapping the gRPC layer; document migration path to Home API |
| User's OAuth consent expires (testing-mode 7-day refresh limit) | High | Medium | Document the "publish to production" upgrade path in onboarding |
| API quota / rate limits hit | Low | Medium | Surface 429s clearly; document quota request flow |
| Activity controls disabled → empty responses | Medium | Medium | `doctor` checks for telltale empty responses and links to the toggle |
| Python dependency conflict with system Python | Medium | Low | Internal venv at `~/.config/cue/google/.venv` |
| GCP project creation flow changes | Low | Low | Setup wizard prints links + copy-pasteable commands rather than scraping the UI |
| User picks wrong account during OAuth | Medium | Low | Clear messaging during consent flow; `doctor` shows which account is bound |

---

## 11. Out of scope (v1)

- GUI / menu bar app
- Native Windows support (PowerShell port)
- Voice input from terminal microphone
- Audio response playback
- Multi-account / account switching beyond `--profile`
- Push notifications back from Google Home to terminal
- Workspace / Google Apps account support
- Newer Google Home API integration (deferred to v2 if deprecation lands)

---

## 12. Success metrics

| ID  | Metric | Target |
|-----|--------|--------|
| SM-1 | Setup time (install → first successful command) | < 15 minutes |
| SM-2 | Command round-trip latency (p50) | < 3 seconds |
| SM-3 | Days between Google-side disruptions | Indefinite (officially supported during v1) |
| SM-4 | Successful auto-refresh rate over a month | > 99% |
| SM-5 | Personal usage frequency | > 10 commands / day |

---

## 13. Glossary

| Term | Definition |
|------|------------|
| **Google Assistant SDK** | Official Google library / API for sending text or audio queries to Assistant |
| **gRPC** | The Google-designed RPC framework the Assistant SDK speaks over |
| **`embeddedassistant.googleapis.com`** | The gRPC endpoint hosting the Assistant SDK |
| **OAuth 2.0** | The auth protocol used by the SDK; consent and refresh tokens stored locally |
| **Device model** | A virtual device template registered against the GCP project |
| **Device instance** | A specific virtual device with a unique ID, derived from a model |
| **Home graph** | Google's representation of the user's connected smart-home devices |
| **Activity controls** | User-level toggles at myactivity.google.com required for the SDK to return non-empty responses |
| **Test user** | An account explicitly allowlisted on the OAuth consent screen while it is in Testing mode |

---

*End of BRD v0.1*
