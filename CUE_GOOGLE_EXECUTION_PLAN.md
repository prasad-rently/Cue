# Cue — Google Engine — Execution Plan

**Project:** Cue (umbrella)
**Component:** `cue-google`
**Version:** 0.1 (Draft)
**Date:** 8 June 2026
**Author:** Gokul
**Related:** `CUE_GOOGLE_BRD.md`, `CUE_README.md`

---

## 1. Architecture overview

```
┌───────────────────────────────────────────────────────────┐
│  User shell                                                │
│  $ cue "turn on the lights"          ← umbrella (typical)  │
│  $ cue-google "turn on the lights"   ← direct (advanced)   │
└──────────────────────────┬────────────────────────────────┘
                           │
                ┌──────────▼────────────┐
                │  bin/cue               │   Umbrella router
                │  (separate repo)       │   (auto-routes by config)
                └──────────┬─────────────┘
                           │
                ┌──────────▼────────────┐
                │  bin/cue-google        │   Engine binary
                │  (bash front-end)      │   - flag parsing
                │                        │   - config loading
                │                        │   - JSON / quiet modes
                └──────────┬─────────────┘
                           │
                ┌──────────▼─────────────┐
                │  lib/python_bridge.sh  │   Activates venv,
                │                        │   forwards to Python
                └──────────┬─────────────┘
                           │
                ┌──────────▼─────────────────────┐
                │  pysrc/cue_google/cli.py       │   Python: gRPC client,
                │  pysrc/cue_google/oauth.py     │   OAuth handling,
                │  pysrc/cue_google/devices.py   │   device-model mgmt
                └──────────┬─────────────────────┘
                           │
                ┌──────────▼─────────────┐
                │  ~/.config/cue/        │   Shared config root
                │   config.toml          │   (default vendor, etc.)
                │   google/              │   Google engine state:
                │     .venv/             │   - internal Python venv
                │     config.toml        │   - engine-specific opts
                │     credentials.json   │   - OAuth tokens
                │     client_secret.json │   - GCP client JSON
                │     device_state.json  │   - device-model state
                └──────────┬─────────────┘
                           │
                           ▼
                embeddedassistant.googleapis.com
                           │
                           ▼
                Google Home graph → devices
```

**Layering rule:** the engine binary (`bin/cue-google`) is stable; Python internals can be rewritten / swapped (e.g., to the Home API in v2) without changing the user contract. The umbrella `cue` lives in its own repo and shells out to engines via PATH — engines must work whether `cue` is installed or not.

---

## 2. Tech stack

| Layer            | Choice                                                  | Why |
|------------------|---------------------------------------------------------|-----|
| Front-end CLI    | Bash 4+ / Zsh-compatible                                | Symmetry with Alexa engine, no Python required for `--help` etc. |
| Python runtime   | Python 3.10+ in internal venv                           | SDK requires it; user shouldn't manage it |
| Argument parsing | `argparse` (Python side) + bash shim                    | Stable, well-understood |
| Config format    | TOML via `tomllib` (3.11+) or `tomli`                   | Same format as Alexa engine |
| JSON output      | `json` stdlib                                           | No deps |
| Auth backend     | `google-auth-oauthlib`                                  | Official |
| gRPC client      | `google-assistant-grpc` (from `google-assistant-sdk`)   | Official |
| Tests            | `pytest` (Python) + `bats-core` (bash)                  | Standard |
| Packaging        | Homebrew tap + curl `install.sh` for Linux              | Symmetry with Alexa engine |
| CI               | GitHub Actions                                          | Free, matrix testing |

---

## 3. Repository structure

```
cue-google/
├── bin/
│   └── cue-google                 # Stable user-facing CLI (bash)
├── lib/
│   ├── python_bridge.sh           # venv activation + Python invocation
│   ├── config.sh                  # Config load / write
│   ├── output.sh                  # JSON / human / quiet formatters
│   └── errors.sh                  # Exit code constants + messages
├── pysrc/
│   └── cue_google/
│       ├── __init__.py
│       ├── cli.py                 # argparse entry, dispatches to subcommands
│       ├── oauth.py               # OAuth flow + token refresh
│       ├── grpc_client.py         # gRPC text-query client
│       ├── devices.py             # device model / instance management
│       ├── doctor.py              # health-check logic
│       ├── config.py              # TOML config
│       └── errors.py              # Exception → exit code mapping
├── share/
│   └── completions/
│       ├── _cue-google            # Zsh
│       └── cue-google.bash        # Bash
├── tests/
│   ├── python/
│   │   ├── test_oauth.py
│   │   ├── test_grpc_client.py
│   │   ├── test_devices.py
│   │   └── test_config.py
│   ├── bash/
│   │   └── cli.bats
│   └── fixtures/
├── docs/
│   ├── INSTALL.md
│   ├── GCP_SETUP.md               # Console walkthrough with screenshots
│   ├── OAUTH_RUNBOOK.md           # "What to do when consent breaks"
│   ├── COMMANDS.md
│   └── HOMEASSISTANT.md
├── pyproject.toml                 # Python project metadata + deps
├── requirements.lock              # Pinned deps
├── install.sh                     # Curl-pipe installer for Linux
├── Formula/cue-google.rb          # Homebrew formula
├── CLAUDE.md                      # Agent context
├── AGENT_RULES.md
├── CUE_GOOGLE_BRD.md
├── CUE_GOOGLE_EXECUTION_PLAN.md
└── README.md
```

---

## 4. Phased roadmap

### Phase 0 — Foundations (4–6 hours)
*Goal: skeleton repo, Python venv bootstrapped, "hello world" gRPC call works.*

| Task | Estimate | Deliverable |
|------|----------|-------------|
| Initialise repo, license, README skeleton | 30m | Empty repo, MIT |
| Author CLAUDE.md + AGENT_RULES.md | 45m | Agent context committed |
| pyproject.toml with pinned google-assistant-sdk deps | 30m | requirements.lock |
| Internal venv bootstrap in lib/python_bridge.sh | 1h | venv auto-created on first run |
| bin/cue-google --help skeleton | 1h | Help text + exit codes |
| Manual smoke-test: OAuth flow + a `--text-query` round-trip | 1.5h | Confirmation that SDK works end-to-end |

**Exit criteria:** A manually-run text query through the raw Python SDK succeeds against the author's Google account.

---

### Phase 1 — MVP (10–14 hours)
*Goal: usable on the author's own setup, covering FR-001 to FR-053.*

| Task | Estimate | Requirements |
|------|----------|--------------|
| pysrc/cue_google/config.py — TOML read/write | 1h | FR-040 |
| pysrc/cue_google/oauth.py — flow + token storage + auto-refresh | 2h | FR-001 to FR-006 |
| pysrc/cue_google/devices.py — model + instance management | 2h | FR-010 to FR-014 |
| pysrc/cue_google/grpc_client.py — text-query client | 2h | FR-020 to FR-025 |
| pysrc/cue_google/doctor.py — health checks | 1.5h | FR-030 |
| pysrc/cue_google/cli.py — argparse wiring | 1.5h | FR-042 |
| bin/cue-google — bash front-end with flag normalisation | 1h | NFR-002 |
| `cue-google setup` — guided GCP walkthrough | 1.5h | FR-007 |
| Manual end-to-end test against author's Google Home | 1h | — |

**Exit criteria:**
- Author can install fresh on a clean Mac in < 15 minutes including GCP setup
- `cue-google doctor` reports all green
- `cue-google "what time is it"` returns a sensible Assistant response

---

### Phase 2 — Hardening (8–10 hours)
*Goal: ready for power-user adoption beyond the author.*

| Task | Estimate | Requirements |
|------|----------|--------------|
| Homebrew formula + tap | 1.5h | FR-060 |
| Linux install.sh | 1h | FR-061 |
| Internal venv self-management & repair | 1.5h | FR-062 |
| pytest suite for Python modules | 2.5h | — |
| bats suite for bash CLI | 1h | — |
| GitHub Actions CI (macOS + Ubuntu matrix) | 1.5h | — |
| Bash + Zsh completions | 1h | UX polish |
| docs/OAUTH_RUNBOOK.md for breakage scenarios | 1h | NFR-006 |
| docs/GCP_SETUP.md with screenshots | 1h | UX |

**Exit criteria:** Anyone with the install command can have a working CLI in < 15 minutes on macOS or Linux.

---

### Phase 3 — Integrations (4–6 hours)
*Goal: composable with the rest of the user's home stack and the Alexa sibling.*

| Task | Estimate | Notes |
|------|----------|-------|
| Home Assistant `shell_command` recipes | 1h | docs/HOMEASSISTANT.md |
| Raycast script command bundle | 1h | macOS power-user UX |
| Verify standalone + umbrella compat (`cue-google` and `cue → cue-google`) | 1h | Engine works with or without umbrella |
| Cron / launchd recipes | 30m | Examples |
| Per-room device-id pattern (kitchen-pi, garage-pi) | 1h | Power-user pattern |

**Exit criteria:** `cue-google` works standalone, and when the umbrella `cue` is also installed, `cue --google "..."` and `cue --both "..."` route correctly.

---

### Phase 4 — Stretch (timeboxed, optional)
- Migration path to the newer Google Home API once GA
- Multi-account / `--profile` support
- Conversation state preservation across calls (`--conversation-state-file`)
- Menu bar app symmetry with the Alexa stretch
- Web UI for device-model and consent management

---

## 5. Milestone roadmap

| Milestone | Target date | Definition of done |
|-----------|-------------|--------------------|
| M0 — Skeleton runs | Week 1 | Phase 0 complete; raw SDK round-trip verified |
| M1 — MVP usable | Week 2 | Phase 1 complete; author uses daily for 5 days |
| M2 — Public-ready | Week 4 | Phase 2 complete; v0.1.0 tagged |
| M3 — Integrated | Week 5 | Phase 3 complete; cross-vendor unified router live |
| M4 — v1.0 | Week 8 | Two weeks of stability; documentation polished |

(Indicative; no hard deadlines.)

---

## 6. Test and validation plan

| Layer | Coverage |
|-------|----------|
| Unit (Python) | oauth, grpc_client (mocked), devices, config, errors |
| Unit (bash) | flag parsing, output formatting, venv bootstrap |
| Integration | doctor, devices, text-query against a sandbox Google account (CI secret) |
| Manual | Real-device verification on the author's Nest fleet before tagged releases |
| Regression | Pin SDK version; CI alerts on upstream releases |

**Acceptance gates per release:**
1. All pytest + bats tests pass on macOS + Ubuntu
2. `cue-google doctor` succeeds on the author's setup
3. `cue-google "test"` round-trips successfully
4. Documentation rebuilt and reviewed

---

## 7. Risk register (engineering view)

| Risk | Owner | Mitigation |
|------|-------|------------|
| Google Assistant SDK fully deprecated mid-v1 | Solo | grpc_client.py is isolated; can be swapped for Home API |
| Author's OAuth client revoked due to inactivity | Solo | Doc warns to make at least one call / month; `doctor` warns at 20 days idle |
| Python 3.10 baseline breaks on older systems | Solo | Internal venv pinned; install.sh checks Python version up front |
| SDK deps conflict with system Python | Solo | Internal venv only — never touch system Python |
| GCP project quota issues | Solo | doctor surfaces quota errors with explanatory text |
| Activity controls toggle becomes default-off for new users | Solo | doctor explicitly tests for it and links to remediation |

---

## 8. Execution prompts (Claude Code / agent-ready)

Same convention as the Alexa engine: pasteable into Claude Code, sequential, each ends with an explicit acceptance check. Assume CLAUDE.md + AGENT_RULES.md are at the repo root.

---

### EP-1 — Bootstrap the repo

```
You are setting up a new project called `cue-google` from the BRD
and execution plan in CUE_GOOGLE_BRD.md and CUE_GOOGLE_EXECUTION_PLAN.md.

Tasks:
1. Read CUE_GOOGLE_BRD.md and CUE_GOOGLE_EXECUTION_PLAN.md fully before
   making any changes.
2. Create the directory structure exactly as specified in section 3
   of the execution plan, but only as empty files with a single-line
   comment per file explaining intent.
3. Write pyproject.toml with project metadata and the following pinned
   deps:
     google-assistant-sdk[samples]
     google-auth-oauthlib
     google-assistant-grpc
     tomli; python_version < "3.11"
   Generate requirements.lock from a `pip-compile` run.
4. Add a minimal README.md naming the project, summarising it, and
   linking to the BRD.
5. Add MIT LICENSE.
6. Initialise git and make one commit titled
   "chore: bootstrap repo skeleton from BRD v0.1".

Acceptance:
- `tree -L 3` matches section 3 of the execution plan
- `git log --oneline` shows exactly one commit
- pyproject.toml is valid TOML; requirements.lock is present
- No file contains executable logic yet — only placeholders
```

---

### EP-2 — Python venv bootstrap and bash bridge

```
You are implementing the internal Python venv management per FR-062
of the BRD.

Tasks:
1. Implement lib/python_bridge.sh:
   - Detects whether ~/.config/cue/google/.venv exists; if not,
     creates it with python3.10+ (refuse older with a clear error)
   - Installs pinned dependencies from requirements.lock into the venv
   - Provides a function `python_call <module> [args...]` that
     activates the venv and runs `python -m cue_google.<module>`
   - Caches a "deps installed" marker file so reinstall does not
     re-run on every call
2. Implement bin/cue-google as a thin shell that:
   - Sources lib/python_bridge.sh
   - Forwards all args to `python_call cli "$@"` for now
   - Handles only --help and --version directly without invoking Python
3. Add a `--reset-venv` flag that nukes ~/.config/cue/google/.venv and
   re-bootstraps.

Acceptance:
- On a clean machine with no venv, `cue-google --version` prints the
  version (no venv needed)
- On a clean machine with no venv, `cue-google doctor` triggers venv
  creation and dep install, then runs doctor
- `cue-google --reset-venv` removes and recreates the venv
- shellcheck passes on all bash files
```

---

### EP-3 — Config and OAuth

```
You are implementing config and OAuth per BRD section 7.1 (FR-001 to
FR-007) and section 7.5 (FR-040 to FR-043).

Tasks:
1. Implement pysrc/cue_google/config.py:
   - Read ~/.config/cue/google/config.toml
   - Provide get(key) and set(key, value)
   - Honour precedence flag > env > config
2. Implement pysrc/cue_google/oauth.py:
   - Run the OAuth installed-app flow using
     google-auth-oauthlib with scopes:
        https://www.googleapis.com/auth/assistant-sdk-prototype
        https://www.googleapis.com/auth/gcm
   - Store credentials at ~/.config/cue/google/credentials.json
     with mode 0600
   - On every call, attempt token refresh; if refresh fails, exit
     with a documented code and a clear message instructing the user
     to run `cue-google login`
3. Implement `cue-google setup` as a guided walkthrough that prints
   copy-pasteable `gcloud` commands for: enabling the Assistant API,
   configuring the OAuth consent screen, and creating a Desktop OAuth
   client. The user provides the path to the downloaded
   client_secret.json; the tool copies it to its config dir.
4. Implement `cue-google login` that runs the OAuth flow standalone.

Acceptance:
- `cue-google setup` walks through a fresh GCP project setup
- `cue-google login` opens a browser, completes consent, writes
  credentials to disk with mode 0600
- `cue-google doctor` (next step) can verify token validity
- No token or refresh token is ever logged
```

---

### EP-4 — Device model and instance management

```
You are implementing device model / instance management per BRD
FR-010 to FR-014.

Tasks:
1. Implement pysrc/cue_google/devices.py with:
   - register_model(manufacturer, product_name, device_type, model_id)
   - list_models() → [{model_id, manufacturer, ...}]
   - register_instance(model_id, device_id, nickname)
   - list_instances() → [{device_id, model_id, nickname}]
   - delete_instance(device_id), delete_model(model_id)
   Use googlesamples.assistant.grpc.assistant_helpers and the Device
   Registration REST API.
2. Wire CLI subcommands:
   `cue-google device-model {register,list,delete}`
   `cue-google device {register,list,delete}`
3. Persist the default device_model_id and device_id in config so the
   user does not have to pass them every call.
4. Validate device_id is unique within the project.

Acceptance:
- `cue-google device-model register --manufacturer Self --product cli
   --type LIGHT --model cli-assistant-1` succeeds and the model is
   listed by `cue-google device-model list`
- `cue-google device register --model cli-assistant-1 --id cli-1`
   succeeds
- Config persists default model + device after first registration
- pytest covers the happy paths
```

---

### EP-5 — Text-query client

```
You are implementing the gRPC text-query client per BRD FR-020
to FR-025 and FR-050 to FR-053.

Tasks:
1. Implement pysrc/cue_google/grpc_client.py:
   - Open a gRPC channel to embeddedassistant.googleapis.com:443 using
     google-auth credentials
   - Build an AssistConfig with text_query, audio_out_config (we ignore
     audio bytes), device_config (model_id + device_id), and the user's
     locale + lat/lng from config
   - Stream the AssistRequest, collect text response chunks, return
     a final string
   - Honour a 15s default timeout (configurable)
2. Wire `cue-google "<text>"` to call this client with the resolved
   device_model_id and device_id from config / flags.
3. Map gRPC errors to documented exit codes:
   UNAUTHENTICATED → 10 (auth)
   PERMISSION_DENIED → 11 (consent issue)
   FAILED_PRECONDITION → 12 (activity controls off)
   UNAVAILABLE → 40 (network)
   DEADLINE_EXCEEDED → 41 (timeout)
   RESOURCE_EXHAUSTED → 42 (quota)
   default → 30 (other upstream)
4. Implement --json to emit {query, response_text, latency_ms,
   request_id, model_id, device_id}.

Acceptance:
- `cue-google "what time is it"` prints a sensible response
- `cue-google --json "what time is it"` prints valid JSON parseable
  by jq
- Network drop triggers exit code 40 with a clear message
- Invalid credentials trigger exit code 10 with a "run cue-google
  login" hint
- pytest covers error mapping with mocked gRPC responses
```

---

### EP-6 — Doctor and discovery

```
You are implementing diagnostics per BRD FR-030 to FR-033.

Tasks:
1. Implement pysrc/cue_google/doctor.py running these checks in order:
   a. Config file exists and is parseable
   b. client_secret.json present
   c. credentials.json present and refresh succeeds
   d. Default device_model_id registered against the project
   e. Default device_id registered against that model
   f. Activity controls heuristic: send a trivial query
      "say test" — if the response is empty, warn that activity
      controls may be off, with a link to myactivity.google.com
   g. Network reachability to embeddedassistant.googleapis.com:443
2. Each check prints PASS / WARN / FAIL with a remediation hint.
3. Support --json to emit a structured doctor report.
4. Support --offline to skip network checks (e.g., on a plane).

Acceptance:
- `cue-google doctor` runs all checks and prints a clear summary
- `cue-google doctor --json` produces valid JSON
- Disabling activity controls produces a WARN with the right link
- Revoking the OAuth client produces a FAIL on check (c) with the
  "run cue-google login" instruction
```

---

### EP-7 — Packaging and CI

```
You are packaging the project per BRD FR-060 to FR-063.

Tasks:
1. Write a Homebrew formula in Formula/cue-google.rb. Test it via
   `brew install --build-from-source ./Formula/cue-google.rb`.
2. Write install.sh for Linux that:
   - Verifies Python 3.10+ is present
   - Downloads the latest tagged release
   - Verifies a SHA256 checksum
   - Installs to /usr/local/bin (fallback to $HOME/.local/bin without
     sudo)
   - Bootstraps the venv
   - Runs `cue-google doctor --offline` to confirm install
3. Set up .github/workflows/ci.yml:
   - shellcheck on bash files
   - pytest on Python modules with coverage > 70%
   - bats on CLI behaviour
   - macos-latest and ubuntu-latest matrix
4. Tag the release as v0.1.0 once CI is green.

Acceptance:
- `brew install ./Formula/cue-google.rb` succeeds on a clean Mac
- `curl -fsSL .../install.sh | bash` succeeds on a clean Ubuntu
- CI passes on both runners; coverage gate enforced
- v0.1.0 git tag exists
```

---

### EP-8 — Integrations and recipes

```
You are wiring the CLI into the broader stack per execution plan
Phase 3.

Tasks:
1. Write docs/HOMEASSISTANT.md with copy-pasteable
   `shell_command:` configuration.yaml entries for:
   - Triggering a Google Home action from an HA automation
   - Asking Assistant a question and capturing the response into
     an HA template sensor
   - Cross-vendor fan-out with the unified `cue` umbrella
2. Write a Raycast script command at docs/raycast/cue-google.sh
   with proper Raycast metadata headers.
3. The unified `cue` umbrella lives in its own separate repo and is
   out of scope for this engine. Add docs/UMBRELLA.md noting that
   the umbrella `cue` discovers `cue-google` via PATH and that this
   engine MUST work standalone whether or not `cue` is installed.
4. Write docs/recipes/per-room-device-id.md showing the pattern of
   registering one device-id per physical room (kitchen-pi,
   garage-pi) so questions like "what's the temperature here" route
   correctly.

Acceptance:
- All recipe files are runnable as-is on the author's setup
- HA YAML validates against a real HA installation
- Raycast bundle imports cleanly
- Per-room device-id doc verified by registering and using two
  distinct device-ids in different commands
```

---

## 9. Open questions

1. Python version floor — 3.10 (broad compat) or 3.11 (stdlib tomllib, no `tomli` dep)?
2. Should `cue-google setup` shell out to `gcloud`, or just print instructions and let the user paste commands?
3. Should the per-room device-id pattern be a first-class CLI concept (`cue-google --room kitchen "..."`) or just a docs recipe?
4. How to handle Google's eventual SDK shutdown — keep the gRPC client behind an interface from day 1, or refactor when needed?
5. Should `--conversation-state-file` be in v1 or strictly Phase 4?

---

## 10. Appendix — exit code table

| Code | Meaning |
|------|---------|
| 0    | Success |
| 1    | Generic failure |
| 2    | Invalid usage |
| 10   | OAuth credentials missing / expired / refresh failed |
| 11   | OAuth consent revoked (PERMISSION_DENIED) |
| 12   | Activity controls off (heuristic FAILED_PRECONDITION) |
| 20   | Device model / instance not found |
| 30   | Other upstream gRPC error |
| 40   | Network UNAVAILABLE |
| 41   | DEADLINE_EXCEEDED (timeout) |
| 42   | Quota / rate-limit RESOURCE_EXHAUSTED |
| 99   | Not yet implemented (development only) |

---

## 11. Cross-reference: parity with Alexa engine

| Concern             | Alexa engine                                  | Google engine                                  |
|---------------------|--------------------------------------------|---------------------------------------------|
| Auth model          | Cookie / TOTP (unofficial)                 | OAuth 2.0 (official)                        |
| API surface         | Reverse-engineered web API                 | Official gRPC                               |
| Stability           | Brittle, breaks every 60–90 days           | Stable but deprecated for new users         |
| Setup time          | < 10 minutes                               | < 15 minutes                                |
| Implementation lang | Pure bash                                  | Bash front-end + Python core                |
| Failure modes       | Cookie expired, format change              | OAuth revoked, activity controls, SDK EOL   |
| Unified router      | `cue --alexa "..."` and `cue --both "..."` (shared with Google engine)             |

The unified `cue` umbrella router lives in its own repo, discovers engines via PATH (`cue-alexa`, `cue-google`), and gives users with one or both engines installed a consistent cross-vendor surface. See `CUE_README.md` for the umbrella spec.

---

*End of Execution Plan v0.1*
