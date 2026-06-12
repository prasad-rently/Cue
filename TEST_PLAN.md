# Cue — Test Plan

Test-case catalog. **TDD is mandatory** (AGENT_RULES §2): every feature in
[`ROADMAP.md`](ROADMAP.md) maps to one or more `TC-*` cases here, and the test is
written + failing before its implementation exists.

- **Test ID:** `TC-<feature>-<nn>` (e.g. `TC-A-20-01` is case 01 for feature CUE-A-20).
- **Type:** `unit` (bats/pytest, no network) · `int` (integration, real account, CI-opt-in) · `man` (manual, real device).
- **Status:** `todo` (not written) · `red` (written, failing) · `green` (passing) · `n/a`.
- **Build now:** cue-alexa foundational units are detailed with Given/When/Then;
  integration/manual cases are listed for traceability and filled in as their EP lands.

Test files live under each component's `tests/`. Naming: `tests/unit/<module>.bats`,
`tests/python/test_<module>.py`, `tests/integration/<area>.bats`.

---

## 1. cue-alexa — foundational units (TDD now)

### CUE-A-20 — Exit codes & error taxonomy (`lib/errors.sh`) → `tests/unit/errors.bats`

| TC | Type | Given / When / Then | Status |
|----|------|---------------------|--------|
| TC-A-20-01 | unit | Sourcing `errors.sh` defines `E_OK=0`, `E_USAGE=2`, `E_AUTH=10`, `E_AUTH_REFRESH=11`, `E_DEVICE_NOT_FOUND=20`, `E_DEVICE_OFFLINE=21`, `E_UPSTREAM=30`, `E_UPSTREAM_PARSE=31`, `E_NETWORK=40`, `E_RATELIMIT=41`, `E_NOTIMPL=99` as readonly. | green |
| TC-A-20-02 | unit | `die "$E_AUTH" "session expired"` → exits 10, message on **stderr**, nothing on stdout. | green |
| TC-A-20-03 | unit | `die`'s message is prefixed (e.g. `cue-alexa: error:`) so callers can grep it. | green |
| TC-A-20-04 | unit | `die` with a code outside the documented table still exits non-zero (never 0). | green |
| TC-A-20-05 | unit | Every constant value matches the plan §10 table exactly (guards against drift). | green |

### CUE-A-18 / CUE-A-19 — Config + precedence (`lib/config.sh`) → `tests/unit/config.bats`

| TC | Type | Given / When / Then | Status |
|----|------|---------------------|--------|
| TC-A-18-01 | unit | `config_get region` on a fixture `config.toml` with `region = "amazon.in"` returns `amazon.in`. | green |
| TC-A-18-02 | unit | `config_get missing_key` returns empty + non-zero (or documented default), never errors out the shell. | green |
| TC-A-18-03 | unit | `config_set default_device "Living Room"` then `config_get default_device` returns `Living Room` (round-trip persists). | green |
| TC-A-18-04 | unit | `config_set` on a fresh `~/.config/cue/alexa/` creates the dir mode 0700 and file mode 0600. | green |
| TC-A-18-05 | unit | Values with spaces / `=` / quotes survive a set→get round-trip intact. | green |
| TC-A-19-01 | unit | Precedence: flag beats env beats file — given file `region=.com`, env `ALEXA_REGION=.de`, flag `--region .in` → resolver returns `.in`. | green |
| TC-A-19-02 | unit | With no flag, env `ALEXA_REGION=.de` beats file `.com` → `.de`. | green |
| TC-A-19-03 | unit | With no flag/env, file value is used. | green |

### CUE-A-21 — Output modes (`lib/output.sh`) → `tests/unit/output.bats`

| TC | Type | Given / When / Then | Status |
|----|------|---------------------|--------|
| TC-A-21-01 | unit | Human mode prints a readable line to stdout. | green |
| TC-A-21-02 | unit | `--json` mode emits valid JSON (pipes clean through `jq .`). | green |
| TC-A-21-03 | unit | `--quiet` suppresses non-error stdout but still emits errors on stderr. | green |
| TC-A-21-04 | unit | `--verbose` emits debug lines to **stderr** only (never pollutes stdout/JSON). | green |
| TC-A-21-05 | unit | `--json` + `--quiet` together still produce parseable JSON (quiet doesn't corrupt it). | green |
| TC-A-21-06 | unit | JSON output escapes embedded quotes/newlines in values. | green |

### CUE-A-12 — Injection-safety & Unicode (`lib/dispatcher.sh`) → `tests/unit/dispatcher.bats`

| TC | Type | Given / When / Then | Status |
|----|------|---------------------|--------|
| TC-A-12-01 | unit | Input `"; rm -rf / ;"` is passed to the upstream as a single literal argument — no subshell, no file deletion (assert via a mock upstream that records argv). | green |
| TC-A-12-02 | unit | Input with backticks `` `id` `` and `$(whoami)` is not expanded. | green |
| TC-A-12-03 | unit | Unicode input (`em—dash`, smart quotes `“”`, `日本語`) reaches the mock upstream byte-for-byte. | green |
| TC-A-12-04 | unit | Empty text argument is rejected with `E_USAGE` (2), not sent upstream. | green |

### CUE-A-06/07/08/13 — Dispatcher mode routing (mocked upstream) → `tests/unit/dispatcher.bats`

| TC | Type | Given / When / Then | Status |
|----|------|---------------------|--------|
| TC-A-06-01 | unit | `dispatch text --device "Echo" "hi"` invokes mock upstream with `-e textcommand:hi -d Echo`. | green |
| TC-A-07-01 | unit | `dispatch speak ... "hi"` uses `-e speak:hi`. | green |
| TC-A-08-01 | unit | `dispatch routine ... "Morning"` uses `-e automation:Morning`. | green |
| TC-A-06-02 | unit | Unknown mode → `E_USAGE` (2). | green |
| TC-A-13-01 | unit | Mock upstream non-zero exit maps to `E_UPSTREAM` (30); unparseable output → 31. | todo |

### CLI front-end (`bin/cue-alexa`) → `tests/unit/cli.bats` (CUE-A-09/20/21 surface)

| TC | Type | Given / When / Then | Status |
|----|------|---------------------|--------|
| TC-A-CLI-01 | unit | `--version` prints contents of `VERSION` and exits 0. | green |
| TC-A-CLI-02 | unit | `--help` prints sectioned help covering all flags/subcommands, exits 0. | green |
| TC-A-CLI-03 | unit | Unknown flag `--nope` exits `E_USAGE` (2) with a usage hint on stderr. | green |
| TC-A-CLI-04 | unit | Stub subcommands (`doctor`/`devices`/`groups`/`routines`/`login`/`config`) print "not yet implemented" and exit 99 (pre-implementation). | green |
| TC-A-CLI-05 | unit | `--cue-engine-info` emits the discovery JSON descriptor (name/version/description/supports) — valid JSON (CUE-X-01). | green |
| TC-A-CLI-06 | unit | `--device` requires an argument; `--device` with no value → `E_USAGE`. | green |

---

## 2. cue-alexa — auth, discovery, packaging (later EPs)

| TC | Feature | Type | Description | Status |
|----|---------|------|-------------|--------|
| TC-A-01-01 | CUE-A-01 | int | `login` credential flow writes session state; `auth_status` returns 0 after. | green |
| TC-A-01-02 | CUE-A-01 | unit | TOTP code generation invoked via `oathtool` with the stored secret (mocked). | todo |
| TC-A-02-01 | CUE-A-02 | unit | `auth_login_cookie <path>` copies a Netscape cookie file into config dir mode 0600. | todo |
| TC-A-02-02 | CUE-A-02 | unit | Malformed cookie file → `E_AUTH` with a clear message, original not stored. | todo |
| TC-A-03-01 | CUE-A-03 | unit | After any auth write, `stat` shows dir 0700 / secret 0600 (no secret logged). | green |
| TC-A-04-01 | CUE-A-04 | unit | Each supported region string maps to the correct upstream domain. | todo |
| TC-A-05-01 | CUE-A-05 | int | Expired cookie → next call exits 10 with "run `cue-alexa login`". | todo |
| TC-A-16-01 | CUE-A-16 | int | `doctor` on healthy setup prints green PASS lines + exit 0. | green |
| TC-A-16-02 | CUE-A-16 | int | `doctor` with missing auth → FAIL line + remediation + non-zero. | green |
| TC-A-13-02 | CUE-A-13 | int | `devices --json` is valid JSON (`jq -e '.[0].serial'` succeeds). | green |
| TC-A-17-01 | CUE-A-17 | unit | Second `devices` call within 24h reads cache (no upstream hit); `--refresh` re-queries. | green |
| TC-A-22-01 | CUE-A-22 | unit | Vendored upstream SHA in `vendor/UPSTREAM.md` matches the committed file (drift guard). | green |
| TC-A-23-01 | CUE-A-23 | int | `brew install --build-from-source ./Formula/cue-alexa.rb` succeeds; binary on PATH. | todo |
| TC-A-24-01 | CUE-A-24 | int | `install.sh` verifies SHA256 and refuses on mismatch. | green |
| TC-A-06-03 | CUE-A-06 | man | Real Echo executes a `textcommand` round-trip < 4s (NFR-001 / CUE-X-03). | todo |
| TC-A-07-02 | CUE-A-07 | man | Real Echo speaks the `--mode speak` string in TTS. | todo |
| TC-A-08-02 | CUE-A-08 | man | Real Echo triggers the named routine. | todo |

---

## 3. cue-google — units (TDD when its EPs run)

| TC | Feature | Type | Description | Status |
|----|---------|------|-------------|--------|
| TC-G-19-01 | CUE-G-19 | unit | `config.get` precedence flag > env > file (pytest, fixture TOML). | green |
| TC-G-19-02 | CUE-G-19 | unit | `config.set`/`get` round-trip persists to `~/.config/cue/google/config.toml`. | green |
| TC-G-13-01 | CUE-G-13 | unit | gRPC `UNAUTHENTICATED` (mocked) maps to exit 10. | green |
| TC-G-13-02 | CUE-G-13 | unit | `PERMISSION_DENIED`→11, `FAILED_PRECONDITION`→12, `UNAVAILABLE`→40, `DEADLINE_EXCEEDED`→41, `RESOURCE_EXHAUSTED`→42, other→30. | green |
| TC-G-14-01 | CUE-G-14 | unit | Logger redacts access/refresh tokens — assert no token substring in captured logs. | green |
| TC-G-11-01 | CUE-G-11 | unit | Query with shell metacharacters reaches the gRPC client as one literal string. | green |
| TC-G-11-02 | CUE-G-11 | unit | Unicode query preserved byte-for-byte into the AssistRequest. | green |
| TC-G-12-01 | CUE-G-12 | unit | gRPC call exceeding timeout aborts cleanly with exit 41 (mocked slow stub). | green |
| TC-G-20-01 | CUE-G-20 | unit | `--json` emits `{query,response_text,latency_ms,request_id,model_id,device_id}` — valid JSON. | green |
| TC-G-06-01 | CUE-G-06 | unit | `register_model(...)` then `list_models()` includes the new model (mocked REST). | green |
| TC-G-07-01 | CUE-G-07 | unit | `register_instance` enforces unique `device_id` within project (duplicate → error). | green |
| TC-G-09-01 | CUE-G-09 | unit | Default model+device persisted to config after first registration. | green |
| TC-G-21-01 | CUE-G-21 | unit | `python_bridge.sh` refuses Python < 3.10 with a clear error (bats, faked `python3`). | green |
| TC-G-21-02 | CUE-G-21 | unit | Missing venv → bootstrap creates it + installs from `requirements.lock`; marker prevents re-install. | todo |
| TC-G-21-03 | CUE-G-21 | unit | `--reset-venv` removes and recreates `.venv`. | green |
| TC-G-03-01 | CUE-G-03 | int | Valid refresh token auto-refreshes; revoked → exit 10 + "run `cue-google login`". | todo |
| TC-G-15-01 | CUE-G-15 | int | `doctor` runs checks a–g, prints PASS/WARN/FAIL each with remediation. | todo |
| TC-G-16-01 | CUE-G-16 | int | Empty response to "say test" → WARN about activity controls + myactivity link. | todo |
| TC-G-17-01 | CUE-G-17 | unit | `doctor --offline` skips network checks and still exits cleanly (NFR-002). | green |
| TC-G-10-01 | CUE-G-10 | man | Real account: `cue-google "what time is it"` returns a sensible response < 4s. | todo |

---

## 4. cue — umbrella router

| TC | Feature | Type | Description | Status |
|----|---------|------|-------------|--------|
| TC-U-04-01 | CUE-U-04 | unit | `cue --version` works with **zero** engines installed (exit 0). | green |
| TC-U-04-02 | CUE-U-04 | unit | `cue --help` lists routing flags + subcommands. | green |
| TC-U-05-01 | CUE-U-05 | unit | Discovery finds fake `cue-alexa`/`cue-google` stubs on a temp PATH via `--cue-engine-info`. | green |
| TC-U-05-02 | CUE-U-05 | unit | A `cue-*` binary returning invalid JSON to `--cue-engine-info` is skipped with a warning, not a crash. | green |
| TC-U-06-01 | CUE-U-06 | unit | `cue engines` lists 0 / 1 / 2 engines depending on temp PATH contents. | green |
| TC-U-01-01 | CUE-U-01 | unit | `cue --alexa "x"` execs the `cue-alexa` stub with `"x"`; absent → clear error + non-zero. | green |
| TC-U-02-01 | CUE-U-02 | unit | `cue alexa devices` execs `cue-alexa devices` (subcommand passthrough). | green |
| TC-U-03-01 | CUE-U-03 | unit | `cue alexa --device "Bedroom" "x"` forwards all args verbatim. | green |
| TC-U-09-01 | CUE-U-09 | unit | Single engine installed + no flags → routes to that engine (fallback). | green |
| TC-U-09-02 | CUE-U-09 | unit | `CUE_DEFAULT=google` with both installed → routes to google. | green |
| TC-U-08-01 | CUE-U-08 | unit | `[devices]` map sends a mapped device name to its configured vendor. | green |
| TC-U-11-01 | CUE-U-11 | unit | `cue --both "x"` runs both stubs in parallel; exit 0 only if both succeed, else non-zero. | green |
| TC-U-11-02 | CUE-U-11 | unit | `--both` with one engine failing aggregates to non-zero and surfaces both stderrs. | green |
| TC-U-07-01 | CUE-U-07 | unit | `cue doctor` aggregates each engine's `doctor --json` into one report. | green |

---

## 5. Cross-cutting

| TC | Feature | Type | Description | Status |
|----|---------|------|-------------|--------|
| TC-X-01-01 | CUE-X-01 | unit | Each engine's `--cue-engine-info` is valid JSON with `name/version/description/supports`. | todo |
| TC-X-02-01 | CUE-X-02 | unit | Each engine runs fully standalone (no `cue` on PATH) for `--help`/`--version`/`config`. | todo |
| TC-X-04-01 | CUE-X-04 | unit | No network call occurs for `--help`/`config`/offline paths (assert via no-network harness). | todo |
| TC-X-05-01 | CUE-X-05 | unit | No code path invokes `sudo`/`doas` (static grep test). | todo |
| TC-X-07-01 | CUE-X-07 | unit | `shellcheck` passes clean on every `*.sh` / `bin/*` (CI gate). | todo |
| TC-X-06-01 | CUE-X-06 | unit | CI matrix (macos-latest + ubuntu-latest) runs bats + pytest green. | todo |

---

## Coverage summary

| Component | Features | Test cases documented |
|-----------|----------|-----------------------|
| cue-alexa | 29 | 40 |
| cue-google | 29 | 20 (units prioritized; more added per EP) |
| cue umbrella | 13 | 14 |
| cross-cutting | 7 | 6 |

P0 unit-testable features have cases now; integration/manual cases are placeholders
until their EP runs (real account/device required). Update `Status` red→green as
each test is written and passes.
