#!/usr/bin/env bats
# Tests for lib/dispatcher.sh — CUE-A-06/07/08/12/13 (mode routing, injection safety).
# Uses the mock upstream (tests/fixtures/mock-amazon/mock_arc.sh) as test data.
# TC-A-06-*, TC-A-07-*, TC-A-08-*, TC-A-12-*, TC-A-13-*. TDD red.

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  LIBS="source '$REPO_ROOT/lib/errors.sh'; source '$REPO_ROOT/lib/output.sh'; source '$REPO_ROOT/lib/dispatcher.sh'; out_init 0 0 0"
  export CUE_ALEXA_UPSTREAM="$REPO_ROOT/tests/fixtures/mock-amazon/mock_arc.sh"
  export MOCK_ARGV_FILE="$BATS_TEST_TMPDIR/argv"
}

# helper: assert the recorded argv file contains an exact line
argv_has() { grep -qxF -- "$1" "$MOCK_ARGV_FILE"; }

@test "TC-A-06-01: text mode + --device builds -d <device> -e textcommand:<text>" {
  run bash -c "$LIBS; MOCK_ARGV_FILE='$MOCK_ARGV_FILE' dispatch text --device 'Living Room' 'turn on the lights'"
  [ "$status" -eq 0 ]
  argv_has "-d"
  argv_has "Living Room"
  argv_has "-e"
  argv_has "textcommand:turn on the lights"
}

@test "TC-A-07-01: speak mode builds -e speak:<text>" {
  run bash -c "$LIBS; MOCK_ARGV_FILE='$MOCK_ARGV_FILE' dispatch speak --device Bedroom 'dinner is ready'"
  [ "$status" -eq 0 ]
  argv_has "speak:dinner is ready"
}

@test "TC-A-08-01: routine mode builds -e automation:<name>" {
  run bash -c "$LIBS; MOCK_ARGV_FILE='$MOCK_ARGV_FILE' dispatch routine --device Bedroom 'Morning Routine'"
  [ "$status" -eq 0 ]
  argv_has "automation:Morning Routine"
}

@test "TC-A-15: --all targets -d ALL" {
  run bash -c "$LIBS; MOCK_ARGV_FILE='$MOCK_ARGV_FILE' dispatch text --all 'good morning'"
  [ "$status" -eq 0 ]
  argv_has "-d"
  argv_has "ALL"
}

@test "TC-A-06-02: unknown mode exits E_USAGE (2)" {
  run bash -c "$LIBS; dispatch bogus --all 'x'"
  [ "$status" -eq 2 ]
}

@test "TC-A-12-04: empty text exits E_USAGE (2) and never calls upstream" {
  run bash -c "$LIBS; MOCK_ARGV_FILE='$MOCK_ARGV_FILE' dispatch text --device Echo ''"
  [ "$status" -eq 2 ]
  [ ! -s "$MOCK_ARGV_FILE" ]
}

@test "TC-A-12-01: shell-injection payload is passed as ONE literal argument; no side effects" {
  sentinel="$BATS_TEST_TMPDIR/SENTINEL"
  : > "$sentinel"
  run bash -c "$LIBS; MOCK_ARGV_FILE='$MOCK_ARGV_FILE' dispatch text --device Echo '; rm -rf \"$sentinel\" ;'"
  [ "$status" -eq 0 ]
  [ -f "$sentinel" ]                                  # not deleted
  argv_has "textcommand:; rm -rf \"$sentinel\" ;"     # passed verbatim, single arg
}

@test "TC-A-12-02: backticks and \$(...) are not expanded" {
  run bash -c "$LIBS; MOCK_ARGV_FILE='$MOCK_ARGV_FILE' dispatch text --device Echo 'say \$(whoami) and \`id\`'"
  [ "$status" -eq 0 ]
  argv_has 'textcommand:say $(whoami) and `id`'
}

@test "TC-A-12-03: Unicode reaches upstream byte-for-byte" {
  run bash -c "$LIBS; MOCK_ARGV_FILE='$MOCK_ARGV_FILE' dispatch text --device Echo 'café — 日本語 “smart”'"
  [ "$status" -eq 0 ]
  argv_has 'textcommand:café — 日本語 “smart”'
}

@test "TC-A-13-01: upstream non-zero exit maps to E_UPSTREAM (30)" {
  run bash -c "$LIBS; MOCK_ARGV_FILE='$MOCK_ARGV_FILE' MOCK_EXIT=7 dispatch text --device Echo 'hi'"
  [ "$status" -eq 30 ]
}
