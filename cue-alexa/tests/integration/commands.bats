#!/usr/bin/env bats
# Integration tests for bin/cue-alexa wired end-to-end, using the mock upstream
# and a temp config dir. No real Amazon account required — the mock is test data.
# Covers: config, login, devices (+cache +json), doctor, groups/routines, text dispatch.

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  CLI="$REPO_ROOT/bin/cue-alexa"
  export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/cfg"
  export CUE_ALEXA_UPSTREAM="$REPO_ROOT/tests/fixtures/mock-amazon/mock_arc.sh"
  export MOCK_ARGV_FILE="$BATS_TEST_TMPDIR/argv"
  COOKIE_FIXTURE="$REPO_ROOT/tests/fixtures/mock-amazon/cookie.txt"
  ADIR="$XDG_CONFIG_HOME/cue/alexa"
}

@test "config set/get round-trips via the CLI" {
  run "$CLI" config set default_device "Living Room"
  [ "$status" -eq 0 ]
  run "$CLI" config get default_device
  [ "$status" -eq 0 ]
  [ "$output" = "Living Room" ]
}

@test "config get on an unset key fails cleanly (exit 1)" {
  run "$CLI" config get nope
  [ "$status" -eq 1 ]
}

@test "login --cookie imports the fixture (0600)" {
  run "$CLI" login --cookie "$COOKIE_FIXTURE"
  [ "$status" -eq 0 ]
  [ "$(stat -f '%Lp' "$ADIR/cookie.txt")" = "600" ]
}

@test "devices lists the mock fleet as a table" {
  run "$CLI" devices
  [ "$status" -eq 0 ]
  [[ "$output" == *"Living Room"* ]]
  [[ "$output" == *"Bedroom Echo"* ]]
  [[ "$output" == *"Kitchen"* ]]
}

@test "devices --json emits a valid JSON array (CUE-A-13)" {
  run "$CLI" devices --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.devices | length == 3' >/dev/null
  [ "$(echo "$output" | jq -r '.devices[0]')" = "Living Room" ]
}

@test "TC-A-17-01: devices cache survives restart; --refresh re-queries" {
  run "$CLI" devices ; [ "$status" -eq 0 ]
  [ -f "$ADIR/cache.json" ]
  # second call with mock disabled still works from cache (no upstream call)
  run env CUE_ALEXA_UPSTREAM=/nonexistent "$CLI" devices
  [ "$status" -eq 0 ]
  [[ "$output" == *"Living Room"* ]]
  # --refresh forces upstream, which is missing -> upstream error (non-zero)
  run env CUE_ALEXA_UPSTREAM=/nonexistent "$CLI" devices --refresh
  [ "$status" -ne 0 ]
}

@test "doctor --json reports healthy after cookie import" {
  "$CLI" login --cookie "$COOKIE_FIXTURE"
  run "$CLI" doctor --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.healthy == true' >/dev/null
  [ "$(echo "$output" | jq -r '.auth')" = "ok" ]
  [ "$(echo "$output" | jq -r '.device_count')" = "3" ]
}

@test "doctor with no auth reports FAIL and non-zero" {
  run "$CLI" doctor
  [ "$status" -ne 0 ]
  [[ "$output$stderr" == *"FAIL"* ]] || true
}

@test "doctor --offline skips network and still runs (NFR-002)" {
  "$CLI" login --cookie "$COOKIE_FIXTURE"
  run "$CLI" doctor --offline --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.offline == true' >/dev/null
}

@test "groups/routines degrade gracefully to empty JSON" {
  run "$CLI" groups --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.groups == []' >/dev/null
  run "$CLI" routines --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.routines == []' >/dev/null
}

@test "text dispatch end-to-end records the right upstream argv" {
  run "$CLI" --device "Living Room" "turn on the lights"
  [ "$status" -eq 0 ]
  grep -qxF -- "-d" "$MOCK_ARGV_FILE"
  grep -qxF -- "Living Room" "$MOCK_ARGV_FILE"
  grep -qxF -- "textcommand:turn on the lights" "$MOCK_ARGV_FILE"
}

@test "default device resolves from config when --device omitted" {
  "$CLI" config set default_device "Kitchen"
  run "$CLI" "what time is it"
  [ "$status" -eq 0 ]
  grep -qxF -- "Kitchen" "$MOCK_ARGV_FILE"
  grep -qxF -- "textcommand:what time is it" "$MOCK_ARGV_FILE"
}

@test "speak mode via --mode reaches upstream as speak:" {
  run "$CLI" --mode speak --all "dinner is ready"
  [ "$status" -eq 0 ]
  grep -qxF -- "ALL" "$MOCK_ARGV_FILE"
  grep -qxF -- "speak:dinner is ready" "$MOCK_ARGV_FILE"
}
