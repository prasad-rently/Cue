# cue-alexa — Validation guide & test data

How to validate the implementation **without an Amazon account** (using the
bundled mock test data), and then against a **real** account.

---

## 1. Test data (what ships for validation)

| File | Purpose |
|------|---------|
| `tests/fixtures/mock-amazon/mock_arc.sh` | Stand-in for `alexa_remote_control.sh`. Records the exact argv it was called with to `$MOCK_ARGV_FILE`, emits a canned 3-device fleet for `-a`, and exits with `${MOCK_EXIT:-0}`. **No network, no eval** — safe and deterministic. |
| `tests/fixtures/mock-amazon/cookie.txt` | A valid Netscape-format cookie file (fake token) for exercising `login --cookie`. |

Two environment variables drive offline validation:

- `CUE_ALEXA_UPSTREAM` — point the engine at the mock instead of the real upstream.
- `XDG_CONFIG_HOME` — redirect config/secrets to a throwaway dir (never touches `~/.config`).
- `MOCK_ARGV_FILE` — where the mock records what it received (so you can assert on it).
- `MOCK_EXIT` — force the mock to fail, to validate error handling.

---

## 2. Run the automated test suite

Prereqs: `bats`, `shellcheck`, `jq`, and `bash` 4+.

```bash
brew install bats-core shellcheck jq bash      # macOS
cd cue-alexa

# Lint
shellcheck bin/cue-alexa lib/*.sh

# Unit + integration tests (58 cases)
bats tests/unit/*.bats tests/integration/*.bats
```

Expected: **all green**, `shellcheck` silent. Each test maps to a `TC-*` id in
[`../TEST_PLAN.md`](../TEST_PLAN.md).

---

## 3. Manual offline walkthrough (mock upstream)

Copy-paste this block — it sets up an isolated sandbox and exercises the whole CLI
against the mock. Nothing here contacts Amazon.

```bash
cd cue-alexa
export XDG_CONFIG_HOME="$(mktemp -d)"
export CUE_ALEXA_UPSTREAM="$PWD/tests/fixtures/mock-amazon/mock_arc.sh"
export MOCK_ARGV_FILE="$(mktemp)"
CLI=./bin/cue-alexa

# 1) basics
$CLI --version                       # -> 0.0.1
$CLI --cue-engine-info | jq .        # -> {"name":"alexa", ...}

# 2) auth via cookie fixture
$CLI login --cookie tests/fixtures/mock-amazon/cookie.txt
stat -f '%Lp' "$XDG_CONFIG_HOME/cue/alexa/cookie.txt"   # -> 600

# 3) config round-trip
$CLI config set default_device "Living Room"
$CLI config get default_device       # -> Living Room

# 4) discovery (served by the mock's canned fleet)
$CLI devices                         # -> table: Living Room / Bedroom Echo / Kitchen
$CLI devices --json | jq '.devices'  # -> ["Living Room","Bedroom Echo","Kitchen"]

# 5) doctor
$CLI doctor --json | jq .            # -> {"auth":"ok","device_count":3,"healthy":true}

# 6) send a command, then inspect EXACTLY what the upstream received
$CLI "turn on the lights"            # uses default_device
cat "$MOCK_ARGV_FILE"
#   -d
#   Living Room
#   -e
#   textcommand:turn on the lights

# 7) speak + broadcast
$CLI --mode speak --all "dinner is ready"
grep -qxF -- 'speak:dinner is ready' "$MOCK_ARGV_FILE" && echo "speak OK"

# 8) injection safety — the payload must arrive as ONE literal argument
touch /tmp/cue_sentinel
$CLI --device Kitchen '; rm -rf /tmp/cue_sentinel ;'
test -f /tmp/cue_sentinel && echo "SAFE: sentinel not deleted"
grep -qxF -- 'textcommand:; rm -rf /tmp/cue_sentinel ;' "$MOCK_ARGV_FILE" && echo "passed verbatim"

# 9) error handling — force the upstream to fail
MOCK_EXIT=7 $CLI --device Kitchen "hi"; echo "exit=$?"   # -> exit=30 (E_UPSTREAM)
```

### What each step validates

| Step | Feature(s) | Test id |
|------|-----------|---------|
| 2 | cookie import + 0600 perms | TC-A-02-01, TC-A-03-01 |
| 3 | config get/set + precedence | TC-A-18-*, TC-A-19-* |
| 4 | device discovery + JSON + cache | TC-A-13-*, TC-A-17-01 |
| 5 | doctor health check | TC-A-16-* |
| 6/7 | text/speak/broadcast dispatch | TC-A-06/07/08/15 |
| 8 | shell-injection safety | TC-A-12-01 |
| 9 | upstream error → exit 30 | TC-A-13-01 |

---

## 4. Validate against a real Amazon account

```bash
# Install (see docs/INSTALL.md) so `cue-alexa` is on PATH, then:
cue-alexa login                 # cookie capture or credentials+TOTP
cue-alexa doctor                # expect green; shows device count + region
cue-alexa devices               # your real Echo fleet
cue-alexa --device "<your Echo>" "what time is it"   # round-trips in < 4s (NFR-001)
```

If `doctor` reports auth failure, see [`docs/AUTH_RUNBOOK.md`](docs/AUTH_RUNBOOK.md).

---

## 5. Interaction model (how a call flows)

```
cue-alexa "turn on the lights"
   │  parse flags, resolve mode/device (flag > env > config)
   ▼
run_text ──► dispatch text --device "Living Room" "turn on the lights"
   │  build argv array (injection-safe): -d "Living Room" -e "textcommand:..."
   ▼
lib/dispatcher.sh ──► $CUE_ALEXA_UPSTREAM -d "Living Room" -e "textcommand:..."
   │  (real: vendor/alexa_remote_control.sh → alexa.amazon.* → Echo)
   ▼
map exit code (0 ok | 30 upstream | 10 auth | 40 network) ──► emit_result (human/JSON)
```
