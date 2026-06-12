#!/usr/bin/env bats
# Tests for bin/cue-alexa CLI front-end skeleton — EP-3.
# TC-A-CLI-01..06. Written before the implementation (TDD red phase).

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  CLI="$REPO_ROOT/bin/cue-alexa"
}

@test "TC-A-CLI-01: --version prints VERSION contents and exits 0" {
  run "$CLI" --version
  [ "$status" -eq 0 ]
  [ "$output" = "$(cat "$REPO_ROOT/VERSION")" ]
}

@test "TC-A-CLI-02: --help prints sectioned help covering flags and subcommands" {
  run "$CLI" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--device"* ]]
  [[ "$output" == *"--mode"* ]]
  [[ "$output" == *"--json"* ]]
  [[ "$output" == *"doctor"* ]]
  [[ "$output" == *"devices"* ]]
  [[ "$output" == *"login"* ]]
}

@test "TC-A-CLI-03: unknown flag exits E_USAGE (2) with a hint on stderr" {
  run --separate-stderr "$CLI" --nope
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"unknown flag"* ]]
}

@test "TC-A-CLI-04: subcommands are routed (config with no args -> usage error, exit 2)" {
  # superseded by tests/integration/commands.bats for full behaviour; here we only
  # confirm the subcommand dispatcher routes without falling through to text dispatch.
  run --separate-stderr "$CLI" config
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"config get"* ]]
}

@test "TC-A-CLI-05: --cue-engine-info emits a valid JSON descriptor" {
  run "$CLI" --cue-engine-info
  [ "$status" -eq 0 ]
  echo "$output" | jq -e . >/dev/null
  [ "$(echo "$output" | jq -r '.name')" = "alexa" ]
  [ "$(echo "$output" | jq -r '.version')" = "$(cat "$REPO_ROOT/VERSION")" ]
  [ "$(echo "$output" | jq -r '.supports | index("text")')" != "null" ]
}

@test "TC-A-CLI-06: --device with no value exits E_USAGE (2)" {
  run --separate-stderr "$CLI" --device
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"--device"* ]]
}
