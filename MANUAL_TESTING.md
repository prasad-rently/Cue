# Cue — Manual testing guide

How to test all three components — automated suites, an **offline** end-to-end
walkthrough (no Amazon/Google account needed), and the **live** checklists.

Test-case IDs referenced here live in [`TEST_PLAN.md`](TEST_PLAN.md).

## 0. Prerequisites

```bash
brew install bats-core shellcheck jq bash          # macOS
# Linux: apt-get install bats shellcheck jq ; ensure bash 4+ and python 3.10+
```

## 1. Automated test suites (run these first)

```bash
# cue-alexa — 61 bats
cd cue-alexa && shellcheck bin/cue-alexa lib/*.sh install.sh \
  && bats tests/unit/*.bats tests/integration/*.bats && cd ..

# cue umbrella — 14 bats
cd cue && shellcheck bin/cue lib/*.sh install.sh share/completions/cue.bash \
  && bats tests/unit/*.bats && cd ..

# cue-google — 6 bats + 55 pytest (pytest needs no google libraries)
cd cue-google \
  && shellcheck bin/cue-google lib/*.sh install.sh share/completions/cue-google.bash \
  && bats tests/bash/*.bats \
  && python3 -m venv .venv && .venv/bin/pip install -q pytest && .venv/bin/python -m pytest -q \
  && cd ..
```
Expected: all green, shellcheck silent. (CI runs the same on macOS + Ubuntu.)

## 2. Offline end-to-end walkthrough (mock upstream, throwaway config)

This installs all three into a temp prefix and exercises them with **no real
account**. The Alexa engine talks to a mock that records the exact argv; the
Google engine's offline paths run without its Python venv.

```bash
# --- sandbox ---
PFX="$(mktemp -d)/opt"; mkdir -p "$PFX"
export XDG_CONFIG_HOME="$(mktemp -d)"
export CUE_ALEXA_UPSTREAM="$PWD/cue-alexa/tests/fixtures/mock-amazon/mock_arc.sh"
export MOCK_ARGV_FILE="$(mktemp)"

# --- install all three (no sudo) ---
PREFIX="$PFX" ./cue-alexa/install.sh
PREFIX="$PFX" ./cue/install.sh
PREFIX="$PFX" ./cue-google/install.sh
export PATH="$PFX/bin:$PATH"

# --- A. cue-alexa standalone ---
cue-alexa --version
cue-alexa login --cookie cue-alexa/tests/fixtures/mock-amazon/cookie.txt   # 0600 cookie
cue-alexa config set default_device "Living Room"
cue-alexa devices --json | jq .                 # 3 mock devices
cue-alexa doctor --json | jq .                  # {"healthy":true,...}
cue-alexa "turn on the lights"                  # uses default device
cat "$MOCK_ARGV_FILE"                            # -> -d "Living Room" -e textcommand:...
cue-alexa --mode speak --all "dinner is ready"
MOCK_EXIT=7 cue-alexa --device X "hi"; echo "exit=$?"   # -> 30 (E_UPSTREAM)

# --- B. cue-google standalone (offline paths; subcommands need the venv+GCP) ---
cue-google --version
cue-google --cue-engine-info | jq .

# --- C. cue umbrella (multi-engine routing) ---
cue --version
cue engines                                      # discovers cue-alexa + cue-google
cue --alexa --device "Living Room" "set a timer for 5 minutes"
cat "$MOCK_ARGV_FILE"                             # routed to the real cue-alexa
cue alexa devices                                # vendor subcommand passthrough

# --- cleanup ---
rm -rf "$(dirname "$PFX")" "$XDG_CONFIG_HOME" "$MOCK_ARGV_FILE"
```

### What each step proves

| Step | Feature | Test id |
|------|---------|---------|
| login --cookie | cookie import + 0600 | TC-A-02-01 |
| devices --json | discovery + cache + JSON | TC-A-13-*, TC-A-17-01 |
| doctor --json | health check | TC-A-16-* |
| "turn on…" + argv | dispatch + injection-safe | TC-A-06-01, TC-A-12-01 |
| MOCK_EXIT=7 | upstream error → 30 | TC-A-13-01 |
| cue engines | PATH discovery | TC-U-05/06 |
| cue --alexa … | explicit routing | TC-U-01-01 |
| cue alexa devices | passthrough | TC-U-02-01 |

## 3. Injection-safety spot check (important)

```bash
touch /tmp/cue_sentinel
cue-alexa --device Kitchen '; rm -rf /tmp/cue_sentinel ;'
test -f /tmp/cue_sentinel && echo "SAFE — payload was passed as one literal arg"
```

## 4. Live validation (needs real accounts — can't run in CI)

- **cue-alexa:** `cue-alexa login` → `doctor` → `cue-alexa --device "<your Echo>" "what time is it"`.
  Runbook: [`cue-alexa/docs/AUTH_RUNBOOK.md`](cue-alexa/docs/AUTH_RUNBOOK.md).
- **cue-google:** follow [`cue-google/VALIDATION.md`](cue-google/VALIDATION.md) §3 —
  `setup` → `login` → `device-model/device register` → `doctor` → `cue-google "what time is it"`.
  The internal Python venv builds on the first command that needs it.
- **umbrella:** with both engines authed, `cue "<text>"` (auto-route), `cue --both "good morning"`,
  `cue doctor` (aggregated).

## 5. One-glance status

```bash
.claude/scripts/state.sh status        # per-component EP/phase progress
grep -c '| green |' TEST_PLAN.md        # passing test cases
```
