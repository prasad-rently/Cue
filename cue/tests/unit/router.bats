#!/usr/bin/env bats
# Tests for the cue umbrella router (CUE-U-*). Uses stub engines as test data.
# Discovery is PATH-based, so each test builds a temp dir with only the engines
# it wants "installed".

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  CUE="$REPO_ROOT/bin/cue"
  STUBS="$REPO_ROOT/tests/fixtures/bin"
  export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/cfg"
  mkdir -p "$XDG_CONFIG_HOME/cue"
  CONF="$XDG_CONFIG_HOME/cue/config.toml"
}

# mk_engines <names...> -> echoes a PATH-ready dir containing only those engines
mk_engines() {
  local d="$BATS_TEST_TMPDIR/eng.$BATS_TEST_NUMBER"; rm -rf "$d"; mkdir -p "$d"
  local n; for n in "$@"; do cp "$STUBS/cue-$n" "$d/cue-$n"; done
  printf '%s' "$d"
}

@test "TC-U-04-01: --version works with zero engines installed" {
  run "$CUE" --version
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "TC-U-04-02: --help lists routing flags and subcommands" {
  run "$CUE" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--alexa"* ]]
  [[ "$output" == *"--both"* ]]
  [[ "$output" == *"engines"* ]]
  [[ "$output" == *"doctor"* ]]
}

@test "TC-U-06-01: engines lists 0, 1, or 2 discovered engines" {
  run env PATH="$(mk_engines):$PATH" "$CUE" engines
  [ "$status" -eq 0 ]; [[ "$output" == *"No engines"* ]]

  run env PATH="$(mk_engines alexa):$PATH" "$CUE" engines
  [ "$status" -eq 0 ]; [[ "$output" == *"alexa"* ]]; [[ "$output" != *"google"* ]]

  run env PATH="$(mk_engines alexa google):$PATH" "$CUE" engines
  [ "$status" -eq 0 ]; [[ "$output" == *"alexa"* ]]; [[ "$output" == *"google"* ]]
}

@test "TC-U-05-01/02: engines --json emits descriptors; invalid-JSON engine is skipped" {
  d="$(mk_engines alexa google)"
  # a broken engine that returns junk for --cue-engine-info must not crash discovery
  printf '#!/usr/bin/env bash\necho not-json\n' > "$d/cue-broken"; chmod +x "$d/cue-broken"
  run env PATH="$d:$PATH" "$CUE" engines --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '. | length == 2' >/dev/null
  echo "$output" | jq -e 'any(.name == "alexa")' >/dev/null
}

@test "TC-U-01-01: --alexa execs cue-alexa with the args" {
  run env PATH="$(mk_engines alexa google):$PATH" "$CUE" --alexa "turn on the lights"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ENGINE=alexa"* ]]
  [[ "$output" == *"turn on the lights"* ]]
}

@test "TC-U-01-01b: --google when not installed errors clearly (exit 3)" {
  run --separate-stderr env PATH="$(mk_engines alexa):$PATH" "$CUE" --google "x"
  [ "$status" -eq 3 ]
  [[ "$stderr" == *"cue-google"* ]]
}

@test "TC-U-02-01: vendor subcommand passes through (cue alexa devices)" {
  run env PATH="$(mk_engines alexa google):$PATH" "$CUE" alexa devices
  [ "$status" -eq 0 ]
  [[ "$output" == *"ENGINE=alexa"* ]]
  [[ "$output" == *"devices"* ]]
}

@test "TC-U-03-01: args after a vendor subcommand are forwarded verbatim" {
  run env PATH="$(mk_engines alexa):$PATH" "$CUE" alexa --device "Bedroom" "lights off"
  [ "$status" -eq 0 ]
  [[ "$output" == *"--device Bedroom lights off"* ]]
}

@test "TC-U-09-01: single-engine fallback routes with no flag" {
  run env PATH="$(mk_engines google):$PATH" "$CUE" "what time is it"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ENGINE=google"* ]]
}

@test "TC-U-09-02: CUE_DEFAULT selects the vendor when both are installed" {
  run env PATH="$(mk_engines alexa google):$PATH" CUE_DEFAULT=google "$CUE" "hello"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ENGINE=google"* ]]
}

@test "TC-U-08-01: per-device routing map sends a device to its configured vendor" {
  printf 'default_vendor = "alexa"\n\n[devices]\n"Bedroom Nest" = "google"\n' > "$CONF"
  run env PATH="$(mk_engines alexa google):$PATH" "$CUE" --device "Bedroom Nest" "dim the lights"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ENGINE=google"* ]]
}

@test "TC-U-11-01: --both runs all engines; exit 0 only if all succeed" {
  run env PATH="$(mk_engines alexa google):$PATH" "$CUE" --both "good morning"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ENGINE=alexa"* ]]
  [[ "$output" == *"ENGINE=google"* ]]
}

@test "TC-U-11-02: --both is non-zero if any engine fails" {
  run env PATH="$(mk_engines alexa google):$PATH" STUB_EXIT_GOOGLE=5 "$CUE" --both "x"
  [ "$status" -ne 0 ]
  [[ "$output" == *"ENGINE=alexa"* ]]
}

@test "TC-U-07-01: doctor aggregates each engine's doctor --json" {
  run env PATH="$(mk_engines alexa google):$PATH" "$CUE" doctor --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.engines | length == 2' >/dev/null
  echo "$output" | jq -e '.healthy == true' >/dev/null
}
