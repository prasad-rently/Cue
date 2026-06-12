# cue-google — Validation guide

Two layers: **offline unit tests** (mocked OAuth/gRPC — no Google account needed)
and a **live checklist** you run once against your own Google account.

---

## 1. Offline unit tests (no google libraries, no network)

Every OAuth/gRPC/device/doctor call is behind a seam that tests patch, and all
google imports are lazy — so the full logic layer is testable with just `pytest`.

```bash
cd cue-google
python3 -m venv .venv && .venv/bin/pip install -q pytest
.venv/bin/python -m pytest -q            # 55 passed
bats tests/bash/cli.bats                  # 6 passed
shellcheck bin/cue-google lib/*.sh install.sh
```

What the unit suite proves:

| Area | Tests | What's asserted |
|------|-------|-----------------|
| config | `test_config.py` | TOML get/set, flag>env>file precedence, 0700/0600 perms |
| errors | `test_errors.py` | gRPC status → exit code (10/11/12/40/41/42), exception taxonomy |
| oauth | `test_oauth.py` | creds 0600, **tokens never logged** (FR-053), redaction, missing→AuthError |
| grpc_client | `test_grpc_client.py` | request built verbatim (injection/unicode safe), error mapping, timeout→41, `--json` shape |
| devices | `test_devices.py` | model/instance register/list/delete, unique device_id, config persistence |
| doctor | `test_doctor.py` | PASS/WARN/FAIL/SKIP orchestration, `--offline` skips network, activity-WARN |
| cli | `test_cli.py` | dispatch, exit-code surfacing, text-query, `--json`, doctor |
| bridge/bin | `tests/bash/cli.bats` | offline `--version/--help/--cue-engine-info`, Python≥3.10 guard, `--reset-venv` |

## 2. Offline manual smoke (no venv needed)

```bash
cd cue-google
./bin/cue-google --version
./bin/cue-google --cue-engine-info | jq .     # {"name":"google",...}
```

## 3. Live validation checklist (requires a Google account)

These steps **cannot** run in CI/sandbox — they need real GCP + OAuth + a Nest
device. Run them once on your machine:

- [ ] `./install.sh` then `cue-google --version` (the venv builds on first real command)
- [ ] `cue-google setup` → create GCP project, enable Assistant API, OAuth client
- [ ] `cue-google config set project_id <id>` and drop `client_secret.json` in place
- [ ] `cue-google login` → browser consent; confirm `credentials.json` is mode 0600
- [ ] `cue-google device-model register ...` and `cue-google device register ...`
- [ ] `cue-google doctor` → all PASS (or a WARN with a clear hint)
- [ ] `cue-google "what time is it"` → sensible response in < 4s (NFR-001)
- [ ] `cue-google --json "weather today"` → valid JSON via `jq`
- [ ] Disable Web & App Activity → `cue-google doctor` shows the activity-controls WARN
- [ ] Pull the network → a query exits **40**; revoke consent → exits **11**

If anything fails, see [`docs/OAUTH_RUNBOOK.md`](docs/OAUTH_RUNBOOK.md).

## Interaction model

```
cue-google "what time is it"
  └─ bin/cue-google (bash)            --version/--help here, no venv
       └─ python_bridge.sh            ensure venv (build once from requirements.lock)
            └─ cue_google.cli         parse, resolve device-id/model (flag>env>config)
                 └─ grpc_client       build AssistConfig, stream to
                    embeddedassistant.googleapis.com → Home graph → device
                 └─ map gRPC status → exit code; print response / JSON
```
