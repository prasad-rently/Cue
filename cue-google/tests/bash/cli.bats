#!/usr/bin/env bats
# Tests for bin/cue-google bash front-end + lib/python_bridge.sh (EP-2).
# Offline paths must work with NO venv; the Python-version guard is unit-tested.

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  CLI="$REPO_ROOT/bin/cue-google"
  export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/cfg"
}

@test "TC-G-CLI-01: --version works with no venv" {
  run "$CLI" --version
  [ "$status" -eq 0 ]
  [ "$output" = "$(cat "$REPO_ROOT/VERSION")" ]
  [ ! -d "$XDG_CONFIG_HOME/cue/google/.venv" ]   # no venv created
}

@test "TC-G-CLI-02: --help lists options and subcommands" {
  run "$CLI" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--device-id"* ]]
  [[ "$output" == *"setup"* ]]
  [[ "$output" == *"doctor"* ]]
}

@test "TC-X-01 (google): --cue-engine-info is a valid descriptor" {
  run "$CLI" --cue-engine-info
  [ "$status" -eq 0 ]
  echo "$output" | jq -e . >/dev/null
  [ "$(echo "$output" | jq -r '.name')" = "google" ]
  [ "$(echo "$output" | jq -r '.version')" = "$(cat "$REPO_ROOT/VERSION")" ]
}

@test "TC-G-21-03: --reset-venv removes the venv dir" {
  mkdir -p "$XDG_CONFIG_HOME/cue/google/.venv"
  run "$CLI" --reset-venv
  [ "$status" -eq 0 ]
  [ ! -d "$XDG_CONFIG_HOME/cue/google/.venv" ]
}

@test "TC-G-21-01: Python-version guard rejects < 3.10" {
  fake="$BATS_TEST_TMPDIR/fakebin"; mkdir -p "$fake"
  cat > "$fake/python3" <<'PY'
#!/usr/bin/env bash
# pretend to be Python 3.9: fail the >=3.10 version check
[ "$1" = "-c" ] && exit 1
echo "Python 3.9.0"
PY
  chmod +x "$fake/python3"
  run bash -c "source '$REPO_ROOT/lib/python_bridge.sh'; PATH='$fake' _cg_find_python"
  [ "$status" -ne 0 ]
}

@test "TC-G-21-01b: guard accepts a real python >= 3.10" {
  run bash -c "source '$REPO_ROOT/lib/python_bridge.sh'; _cg_find_python"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}
