# Cue — Feature Roadmap

Feature-level roadmap derived from the BRDs and execution plans. Each **feature
ID** is a deliverable unit of user value, mapped to its source requirements
(`FR-*`/`NFR-*`), the execution prompt/phase that ships it, and a status.

- **ID scheme:** `CUE-<scope>-<nn>` — scope ∈ `U` (umbrella), `A` (Alexa), `G` (Google), `X` (cross-cutting).
- **Status:** `todo` · `in_progress` · `blocked` · `done`. Mirrors `.claude/state/execution-state.json`.
- **Authority:** the BRDs win on any conflict. Resolve `FR-*` via `.claude/cache/requirements-index.json`.
- **Build order:** Alexa engine → Google engine → umbrella (it only routes once an engine exists).

Legend for priority: **P0** must-have for v0.1.0 · **P1** important · **P2** polish/stretch.

---

## CUE-A — Alexa engine (`cue-alexa`)

| ID | Feature | Requirements | Ships in | Priority | Status |
|----|---------|--------------|----------|----------|--------|
| CUE-A-01 | Credential + TOTP auth (interactive) | FR-001, FR-007 | EP-4 | P0 | todo |
| CUE-A-02 | Netscape cookie-capture auth fallback | FR-002 | EP-4 | P0 | todo |
| CUE-A-03 | Secure session storage (`~/.config/cue/alexa/`, 0600) | FR-003, NFR-004 | EP-4 | P0 | todo |
| CUE-A-04 | Multi-region support (`.com/.co.uk/.de/.in/…`) | FR-004 | EP-4 | P0 | todo |
| CUE-A-05 | Auto cookie refresh near expiry; expiry detection (`exit 10`) | FR-005, FR-006 | EP-4/EP-5 | P1 | todo |
| CUE-A-06 | `textcommand:` mode (NLU-interpreted) | FR-010, FR-013 | EP-5 | P0 | todo |
| CUE-A-07 | `speak:` mode (TTS, no interpretation) | FR-011 | EP-5 | P0 | todo |
| CUE-A-08 | `automation:` mode (trigger named routine) | FR-012 | EP-5 | P0 | todo |
| CUE-A-09 | `--device` single-Echo targeting | FR-014 | EP-3/EP-5 | P0 | todo |
| CUE-A-10 | `--all` broadcast to every Echo | FR-015 | EP-5 | P1 | todo |
| CUE-A-11 | `--group` device-group targeting | FR-016 | EP-5 | P1 | todo |
| CUE-A-12 | Shell-injection-safe input + Unicode handling | FR-017, FR-018 | EP-5 | P0 | todo |
| CUE-A-13 | `devices` listing (name/serial/type/online) | FR-020 | EP-6 | P0 | todo |
| CUE-A-14 | `groups` listing | FR-021 | EP-6 | P1 | todo |
| CUE-A-15 | `routines` listing (name + ID) | FR-022 | EP-6 | P1 | todo |
| CUE-A-16 | `doctor` health check (auth/expiry/devices/region/last-call) | FR-023, NFR-008 | EP-6 | P0 | todo |
| CUE-A-17 | 24h discovery cache + `doctor --refresh` | FR-024 | EP-6 | P1 | todo |
| CUE-A-18 | TOML config read/write + `config get/set` | FR-030, FR-033 | EP-4 | P0 | todo |
| CUE-A-19 | Override precedence flag > env > config | FR-031, FR-032 | EP-4 | P0 | todo |
| CUE-A-20 | Documented exit codes + error taxonomy | FR-040, FR-044 | EP-3/EP-5 | P0 | todo |
| CUE-A-21 | `--json` / `--quiet` / `--verbose` output modes | FR-041, FR-042, FR-043 | EP-3/EP-6 | P0 | todo |
| CUE-A-22 | Vendored, pinned `alexa-remote-control.sh` | FR-053, NFR-005 | EP-2 | P0 | todo |
| CUE-A-23 | Homebrew formula (macOS) | FR-050 | EP-7 | P1 | todo |
| CUE-A-24 | Linux curl `install.sh` (SHA-verified) | FR-051 | EP-7 | P1 | todo |
| CUE-A-25 | Self-update check on `doctor` (opt-out) | FR-052 | EP-7 | P2 | todo |
| CUE-A-26 | Bash + Zsh shell completions | — (plan §4 P2) | EP-7 | P2 | todo |
| CUE-A-27 | Home Assistant `shell_command` recipes | UC-06 | EP-8 | P2 | todo |
| CUE-A-28 | Raycast / cron / launchd recipes | G7 | EP-8 | P2 | todo |
| CUE-A-29 | Auth-breakage runbook | NFR-007 | EP-7/EP-8 | P1 | todo |

---

## CUE-G — Google engine (`cue-google`)

| ID | Feature | Requirements | Ships in | Priority | Status |
|----|---------|--------------|----------|----------|--------|
| CUE-G-01 | OAuth 2.0 flow (assistant-sdk-prototype + gcm scopes) | FR-001, FR-005 | EP-3 | P0 | todo |
| CUE-G-02 | Secure OAuth credential storage (0600) | FR-002, NFR-004 | EP-3 | P0 | todo |
| CUE-G-03 | Automatic token refresh + re-consent fallback | FR-003, FR-006 | EP-3 | P0 | todo |
| CUE-G-04 | `login` (idempotent re-consent) | FR-004 | EP-3 | P0 | todo |
| CUE-G-05 | `setup` guided GCP onboarding (copy-paste `gcloud`) | FR-007, G4 | EP-3 | P0 | todo |
| CUE-G-06 | Device-model register | FR-010, FR-014 | EP-4 | P0 | todo |
| CUE-G-07 | Device-instance register/list/delete | FR-011 | EP-4 | P0 | todo |
| CUE-G-08 | `--device-id` virtual-device identity | FR-012 | EP-4/EP-5 | P0 | todo |
| CUE-G-09 | Persist default device-model-id + device-id | FR-013 | EP-4 | P0 | todo |
| CUE-G-10 | Text-query gRPC client (+ response on stdout) | FR-020, FR-021 | EP-5 | P0 | todo |
| CUE-G-11 | Injection-safe input + Unicode handling | FR-023, FR-024 | EP-5 | P0 | todo |
| CUE-G-12 | Configurable gRPC timeout (default 15s) | FR-025 | EP-5 | P0 | todo |
| CUE-G-13 | gRPC error → exit-code mapping (10/11/12/40/41/42) | FR-052, NFR-007 | EP-5 | P0 | todo |
| CUE-G-14 | Token-safe logging (never log tokens) | FR-053 | EP-3/EP-5 | P0 | todo |
| CUE-G-15 | `doctor` health check (OAuth/reachability/model/project) | FR-030 | EP-6 | P0 | todo |
| CUE-G-16 | Activity-controls heuristic check | constraint §9 | EP-6 | P1 | todo |
| CUE-G-17 | `doctor --offline` + `--json` | NFR-002, FR-033 | EP-6 | P1 | todo |
| CUE-G-18 | `device-model list` / `device list` | FR-031, FR-032 | EP-6 | P1 | todo |
| CUE-G-19 | TOML config + `config get/set` + precedence | FR-040, FR-041, FR-042, FR-043 | EP-3 | P0 | todo |
| CUE-G-20 | `--json` structured output (query/response/latency/req-id) | FR-051 | EP-5 | P0 | todo |
| CUE-G-21 | Internal Python venv self-management + `--reset-venv` | FR-062, NFR-005 | EP-2 | P0 | todo |
| CUE-G-22 | Pinned Python deps + deprecation surfacing | FR-063 | EP-1/EP-2 | P0 | todo |
| CUE-G-23 | Homebrew formula (macOS) | FR-060 | EP-7 | P1 | todo |
| CUE-G-24 | Linux curl `install.sh` (Python-checked, SHA-verified) | FR-061 | EP-7 | P1 | todo |
| CUE-G-25 | Bash + Zsh shell completions | — (plan §4 P2) | EP-7 | P2 | todo |
| CUE-G-26 | Home Assistant `shell_command` recipes | UC-05 | EP-8 | P2 | todo |
| CUE-G-27 | Raycast / cron + per-room device-id recipes | G7 | EP-8 | P2 | todo |
| CUE-G-28 | OAuth/SDK-deprecation runbook | NFR-006 | EP-7/EP-8 | P1 | todo |
| CUE-G-29 | Home API migration path (isolated gRPC layer) | G11 | EP-5 | P1 | todo |

---

## CUE-U — Umbrella router (`cue`)

| ID | Feature | Requirements | Ships in | Priority | Status |
|----|---------|--------------|----------|----------|--------|
| CUE-U-01 | Explicit vendor routing (`--alexa`/`--google`) | README §3/§4 | P0 | P0 | todo |
| CUE-U-02 | Vendor subcommand passthrough (`cue alexa …`) | README §3 | P0 | P0 | todo |
| CUE-U-03 | Verbatim arg forwarding to engines | README §3 | P0 | P0 | todo |
| CUE-U-04 | `--version` / `--help` (works with 0 engines) | README §8 | P0 | P0 | todo |
| CUE-U-05 | Engine discovery via `cue-*` glob + `--cue-engine-info` | README §5 | P1 | P0 | todo |
| CUE-U-06 | `cue engines` listing | README §8 | P1 | P0 | todo |
| CUE-U-07 | `cue doctor` cross-engine aggregator | README §8 | P1 | P1 | todo |
| CUE-U-08 | Per-device routing table (`[devices]` map) | README §4 | P2 | P1 | todo |
| CUE-U-09 | Default-vendor fallback chain + single-engine fallback | README §4 | P2 | P0 | todo |
| CUE-U-10 | Interactive vendor prompt (save-as-default) | README §4 | P2 | P1 | todo |
| CUE-U-11 | `--both` parallel fan-out + exit-code aggregation | README §4/§8 | P3 | P1 | todo |
| CUE-U-12 | Homebrew formula + Linux `install.sh` | README §7 P4 | P4 | P2 | todo |
| CUE-U-13 | Bash + Zsh completions | README §7 P5 | P5 | P2 | todo |

---

## CUE-X — Cross-cutting (both engines)

| ID | Feature | Requirements | Ships in | Priority | Status |
|----|---------|--------------|----------|----------|--------|
| CUE-X-01 | `--cue-engine-info` JSON descriptor (discovery contract) | README §5 | A:EP-3 / G:EP-2 | P0 | todo |
| CUE-X-02 | Standalone operation (works without umbrella) | README §5, plan §3 | A:EP-8 / G:EP-8 | P0 | todo |
| CUE-X-03 | < 4s round-trip latency | NFR-001 | A:EP-5 / G:EP-5 | P1 | todo |
| CUE-X-04 | No telemetry without opt-in | NFR-003 | both | P0 | todo |
| CUE-X-05 | No sudo/root required | NFR-006(A)/NFR-005(G) | both | P0 | todo |
| CUE-X-06 | `bats`/`pytest` test suites + GitHub Actions CI matrix | plan §6 | A:EP-7 / G:EP-7 | P1 | todo |
| CUE-X-07 | shellcheck-clean across all bash | conventions | every EP | P0 | todo |

---

## Open decisions that gate features

These are unresolved (`.claude/cache/decisions.md`) and may **block** the feature noted:

| Affects | Open question |
|---------|---------------|
| CUE-A-04 | Region default — IP-geolocation auto-detect vs. always prompt? |
| CUE-A-22 | Abstract upstream fully so swapping to `alexa-remote2` is one line? |
| CUE-A-23 | Bundle `oath-toolkit`/`jq` as brew deps vs. document as prerequisites? |
| CUE-G-19 | Python floor 3.10 (needs `tomli`) vs. 3.11 (stdlib `tomllib`)? |
| CUE-G-05 | `setup` shells out to `gcloud` vs. prints instructions only? |
| CUE-G-27 | Per-room device-id as first-class `--room` flag vs. docs recipe? |
| CUE-G-29 | Keep gRPC behind an interface from day 1 vs. refactor on deprecation? |

---

## Counts (v0.1.0 scope)

| Scope | Features | P0 | P1 | P2 |
|-------|----------|----|----|----|
| Alexa (CUE-A) | 29 | 14 | 8 | 7 |
| Google (CUE-G) | 29 | 17 | 8 | 4 |
| Umbrella (CUE-U) | 13 | 5 | 5 | 3 |
| Cross-cutting (CUE-X) | 7 | 4 | 3 | 0 |
| **Total** | **78** | **40** | **24** | **14** |

_Status is mirrored from `.claude/state/execution-state.json`; update both when a feature lands._
