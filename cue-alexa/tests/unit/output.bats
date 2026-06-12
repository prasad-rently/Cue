#!/usr/bin/env bats
# Tests for lib/output.sh — CUE-A-21 (output modes: human / --json / --quiet / --verbose).
# TC-A-21-01..06. Written before the implementation (TDD red phase).
#
# API under test:
#   out_init <json:0|1> <quiet:0|1> <verbose:0|1>
#   out_info <msg>            -> human line on stdout (suppressed when quiet or json)
#   out_error <msg>           -> error on stderr, always (never suppressed by quiet)
#   out_debug <msg>           -> debug on stderr, only when verbose
#   emit_result <human> <json>-> mode-aware result: json payload in json mode, else human
#   json_escape <str>         -> jq-encoded JSON string (quoted, escaped)

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  OUT="$REPO_ROOT/lib/output.sh"
}

@test "TC-A-21-01: human mode prints a readable line to stdout" {
  run --separate-stderr bash -c "source '$OUT'; out_init 0 0 0; out_info 'lights on'"
  [ "$status" -eq 0 ]
  [ "$output" = 'lights on' ]
  [ -z "$stderr" ]
}

@test "TC-A-21-02: --json mode emits valid JSON" {
  run --separate-stderr bash -c "source '$OUT'; out_init 1 0 0; emit_result 'human text' '{\"ok\":true}'"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e . >/dev/null
  [ "$(echo "$output" | jq -r '.ok')" = 'true' ]
}

@test "TC-A-21-03: --quiet suppresses info on stdout but errors still reach stderr" {
  run --separate-stderr bash -c "source '$OUT'; out_init 0 1 0; out_info 'noise'; out_error 'boom'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [[ "$stderr" == *"boom"* ]]
}

@test "TC-A-21-04: --verbose emits debug to stderr only (stdout clean)" {
  run --separate-stderr bash -c "source '$OUT'; out_init 0 0 1; out_debug 'tracing'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [[ "$stderr" == *"tracing"* ]]
}

@test "TC-A-21-04b: debug is silent without --verbose" {
  run --separate-stderr bash -c "source '$OUT'; out_init 0 0 0; out_debug 'tracing'"
  [ -z "$output" ]
  [ -z "$stderr" ]
}

@test "TC-A-21-05: --json + --quiet still produces parseable JSON" {
  run --separate-stderr bash -c "source '$OUT'; out_init 1 1 0; emit_result 'human' '{\"n\":1}'"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e . >/dev/null
  [ "$(echo "$output" | jq -r '.n')" = '1' ]
}

@test "TC-A-21-06: json_escape escapes quotes/newlines into valid JSON" {
  run bash -c "source '$OUT'; json_escape \$'a\"b\nc' | jq -e . >/dev/null && json_escape \$'a\"b\nc'"
  [ "$status" -eq 0 ]
  [ "$output" = '"a\"b\nc"' ]
}
