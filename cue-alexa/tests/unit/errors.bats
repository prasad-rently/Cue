#!/usr/bin/env bats
# Tests for lib/errors.sh — CUE-A-20 (exit codes & error taxonomy).
# TC-A-20-01..05. Written before the implementation (TDD red phase).

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  ERRORS="$REPO_ROOT/lib/errors.sh"
}

@test "TC-A-20-01: defines all documented exit-code constants (plan §10)" {
  source "$ERRORS"
  [ "$E_OK" -eq 0 ]
  [ "$E_FAIL" -eq 1 ]
  [ "$E_USAGE" -eq 2 ]
  [ "$E_AUTH" -eq 10 ]
  [ "$E_AUTH_REFRESH" -eq 11 ]
  [ "$E_DEVICE_NOT_FOUND" -eq 20 ]
  [ "$E_DEVICE_OFFLINE" -eq 21 ]
  [ "$E_UPSTREAM" -eq 30 ]
  [ "$E_UPSTREAM_PARSE" -eq 31 ]
  [ "$E_NETWORK" -eq 40 ]
  [ "$E_RATELIMIT" -eq 41 ]
  [ "$E_NOTIMPL" -eq 99 ]
}

@test "TC-A-20-05: exit-code constants are readonly (drift guard)" {
  run bash -c "source '$ERRORS'; E_AUTH=999"
  [ "$status" -ne 0 ]
}

@test "TC-A-20-02: die exits with given code; message on stderr; stdout empty" {
  run --separate-stderr bash -c "source '$ERRORS'; die \"\$E_AUTH\" 'session expired'"
  [ "$status" -eq 10 ]
  [ -z "$output" ]
  [[ "$stderr" == *"session expired"* ]]
}

@test "TC-A-20-03: die message carries a greppable prefix" {
  run --separate-stderr bash -c "source '$ERRORS'; die \"\$E_USAGE\" 'bad flag'"
  [[ "$stderr" == *"cue-alexa: error:"* ]]
}

@test "TC-A-20-04: die with an undocumented code still exits non-zero" {
  run bash -c "source '$ERRORS'; die 7 'weird'"
  [ "$status" -eq 7 ]
}
