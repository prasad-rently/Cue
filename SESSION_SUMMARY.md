# Cue — Development Summary (session handoff)

A resume-point for picking the project back up. Repo:
**https://github.com/prasad-rently/Cue** (public). **Released v0.1.1.** 19 PRs merged.

> Headline: **`cue-google` works live and controls real smart-home devices.**
> `cue-google "turn off bedroom tube light"` → the light turns off.

---

## What it is
A family of POSIX CLI tools that pipe plain-text commands from the terminal to
voice assistants. Built from the BRDs/execution plans in the repo root
(`CUE_README.md`, `CUE_{ALEXA,GOOGLE}_BRD.md` + `_EXECUTION_PLAN.md`).

## The three components
| Component | What | Status |
|-----------|------|--------|
| **`cue-google`** | Google Assistant engine (bash + Python gRPC, official Assistant SDK) | ✅ **WORKING live** — controls real devices |
| **`cue-alexa`** | Amazon Alexa engine (pure bash, wraps `alexa-remote-control`) | ⚠️ Built + tested, **blocked by Amazon** |
| **`cue`** | Umbrella router (discovers `cue-*` on PATH, routes by config/flags) | ✅ Working |

**Tests:** 68 (cue-alexa bats) + 11 (cue bats) + 6 (cue-google bats) + 59
(cue-google pytest) = **144 green**, shellcheck clean, CI on macOS + Ubuntu.
All three at v0.1.1. Installed at `~/.local/bin/{cue,cue-alexa,cue-google}`.

## ✅ What works (validated on real hardware)
```bash
cue-google "turn off bedroom tube light"   # → "Alright, turning the Bedroom Tube Light off." (it turns off)
cue-google "what time is it"               # → real answer
cue-google --json "weather in chennai"     # → {query, response_text, latency_ms, ...}
cue "turn off bedroom tube light"          # umbrella routes to Google (default_vendor=google)
answer=$(cue-google --quiet "...")         # scriptable
```

## ⚠️ What's blocked
**cue-alexa** — the account is **Amazon India**, and Amazon **decommissioned the
India web Alexa API/csrf** that the unofficial approach depends on. Commands
return HTTP 200 but never execute. **Amazon's deprecation, not a code defect.**
Would work where the web API survives.

## The user's Google setup (already done)
- Google account: **India** (country IN); GCP project **`scriptcli`**, Assistant API enabled
- Desktop OAuth client; consent screen in **Testing** mode (user added as test user)
- Registered: device model `scriptcli-cli-assistant-1`, device `cli-device-1`
- Config + secrets under `~/.config/cue/google/` (0700/0600)
- Real controllable device: **"Bedroom Tube Light"**
- **Weekly caveat (Google rule):** Testing-mode refresh token expires ~7 days →
  `cue-google login` again, or publish the OAuth consent screen to *Production*.

## 10 live-only bugs found & fixed (PRs #8–#19), each with a regression test
1. Password echoed to terminal (`read` without `-s`)
2. Alexa auth never wired into the upstream (`setup_upstream_env`)
3. `set -e` abort killed all real Alexa commands
4. Alexa device-list polluted with upstream progress chatter
5. Alexa TTS locale hardcoded `de-DE` (silent on non-German accounts)
6. cue-google `grpcio==1.68.1` had no Python-3.14 wheel (venv build failed)
7. protobuf 7.x incompatible with SDK's old `_pb2` (force pure-Python impl)
8. Device Registration API needed snake_case + `project_id` (was HTTP 400)
9. Empty answers — needed `screen_out_config` + HTML→text extraction
10. OAuth access token never auto-refreshed (`UNAUTHENTICATED` after ~1h)

## Key files
- **Tracking:** `.claude/state/execution-state.json` (mutate via `.claude/scripts/state.sh`),
  `ROADMAP.md` (78 features), `TEST_PLAN.md`, `AGENT_RULES.md` (TDD mandatory), `CLAUDE.md`
- **cue-google docs:** `README.md`, `docs/CONNECTING_DEVICES.md`, `docs/MANUAL_TEST_RUN.md`,
  `docs/GCP_SETUP.md`, `docs/OAUTH_RUNBOOK.md`, `docs/COMMANDS.md`, `VALIDATION.md`
- **cue-alexa docs:** `docs/AUTH_RUNBOOK.md`, `VALIDATION.md`, `VENDORING.md`
- **Root:** `MANUAL_TESTING.md` (all-three offline walkthrough)
- **Test data:** `cue-alexa/tests/fixtures/mock-amazon/` (mock upstream + cookie);
  cue-google mocks all google calls via lazy imports (unit-testable w/o google libs)

## Conventions / gotchas
- TDD: write test → red → green → refactor. bash: `set -euo pipefail`, shellcheck-clean, secrets 0600.
- Installed copies (`~/.local/bin`) are **snapshots** → re-run `./<comp>/install.sh` after `git pull`.
- Work on branches off `main` → PR → merge (all 19 PRs done this way).
- macOS default bash is 3.2 → scripts target bash 4+; use `/opt/homebrew/bin/bash`.
  Toolchain installed: bats-core, shellcheck, bash 5, oath-toolkit, jq; Python 3.14.
- `cue-google device list` shows the **virtual SDK identity** (`cli-device-1`), NOT smart
  bulbs — IoT devices live in the Google Home graph (paired via the Google Home app).

## Open / possible next steps
- Publish OAuth consent screen to Production (removes the weekly re-login)
- `cue-google selftest` command (parallel to the Alexa one)
- Homebrew tap (parked): needs `prasad-rently/homebrew-tap` + monorepo formula fixes
- Alexa India: only possible avenue is the refresh-token device-login (alexa-cookie-cli), uncertain
- Confirm GitHub Actions is enabled (CI workflow is at repo-root `.github/workflows/ci.yml`)

## Resume quickly
```bash
cd ~/Github/Cue && git pull
cue-google doctor && cue-google "what time is it"     # confirm Google still authed
# if auth fails: cue-google login
```
