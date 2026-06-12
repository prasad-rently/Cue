#!/usr/bin/env bats
# Tests that bin/cue-alexa resolves its own real path before locating lib/*.sh,
# so the binary works when symlinked onto PATH (a common install pattern) and
# stays discoverable by the `cue` umbrella. Written before the fix (TDD red).

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  CLI="$REPO_ROOT/bin/cue-alexa"
  LINK_DIR="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$LINK_DIR"
  LINK="$LINK_DIR/cue-alexa"
  ln -s "$CLI" "$LINK"
}

@test "TC-A-LINK-01: --version works via a symlink on PATH" {
  run "$LINK" --version
  [ "$status" -eq 0 ]
  [ "$output" = "$(cat "$REPO_ROOT/VERSION")" ]
}

@test "TC-A-LINK-02: --cue-engine-info works via a symlink (umbrella discovery)" {
  run "$LINK" --cue-engine-info
  [ "$status" -eq 0 ]
  echo "$output" | jq -e . >/dev/null
  [ "$(echo "$output" | jq -r '.name')" = "alexa" ]
}

@test "TC-A-LINK-03: works through a chain of symlinks" {
  local link2="$LINK_DIR/cue-alexa-2"
  ln -s "$LINK" "$link2"
  run "$link2" --version
  [ "$status" -eq 0 ]
  [ "$output" = "$(cat "$REPO_ROOT/VERSION")" ]
}
