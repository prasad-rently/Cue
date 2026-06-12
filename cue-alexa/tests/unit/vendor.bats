#!/usr/bin/env bats
# Tests for the vendored upstream — CUE-A-22 (TC-A-22-01).
# Offline drift guard: the committed script must match the SHA-256 recorded in
# vendor/UPSTREAM.md. Catches accidental edits and silent re-pins.

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$REPO_ROOT/vendor/alexa_remote_control.sh"
  UPSTREAM="$REPO_ROOT/vendor/UPSTREAM.md"
}

@test "TC-A-22-01: vendored script exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "TC-A-22-01: vendored script SHA-256 matches vendor/UPSTREAM.md" {
  recorded="$(grep -oE '[0-9a-f]{64}' "$UPSTREAM" | head -1)"
  [ -n "$recorded" ]
  actual="$(shasum -a 256 "$SCRIPT" | awk '{print $1}')"
  [ "$actual" = "$recorded" ]
}
