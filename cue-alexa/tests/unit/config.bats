#!/usr/bin/env bats
# Tests for lib/config.sh — CUE-A-18 / CUE-A-19 (config + precedence).
# TC-A-18-01..05, TC-A-19-01..03. TDD red phase.
#
# Isolation: XDG_CONFIG_HOME is pointed at a temp dir so tests never touch the
# real ~/.config. Config lives at $XDG_CONFIG_HOME/cue/alexa/config.toml.

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  CFG="$REPO_ROOT/lib/config.sh"
  export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/cfg"
  mkdir -p "$XDG_CONFIG_HOME/cue/alexa"
  CONFFILE="$XDG_CONFIG_HOME/cue/alexa/config.toml"
}

@test "TC-A-18-01: config_get reads a key from config.toml" {
  printf 'region = "amazon.in"\n' > "$CONFFILE"
  run bash -c "source '$CFG'; config_get region"
  [ "$status" -eq 0 ]
  [ "$output" = "amazon.in" ]
}

@test "TC-A-18-02: config_get on a missing key returns non-zero and empty" {
  printf 'region = "amazon.in"\n' > "$CONFFILE"
  run bash -c "source '$CFG'; config_get nope"
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

@test "TC-A-18-03: config_set then config_get round-trips" {
  run bash -c "source '$CFG'; config_set default_device 'Living Room'; config_get default_device"
  [ "$status" -eq 0 ]
  [ "$output" = "Living Room" ]
}

@test "TC-A-18-04: config_set creates dir 0700 and file 0600" {
  rm -rf "$XDG_CONFIG_HOME"
  run bash -c "source '$CFG'; config_set region amazon.com"
  [ "$status" -eq 0 ]
  [ "$(stat -f '%Lp' "$XDG_CONFIG_HOME/cue/alexa")" = "700" ]
  [ "$(stat -f '%Lp' "$XDG_CONFIG_HOME/cue/alexa/config.toml")" = "600" ]
}

@test "TC-A-18-05: values with spaces, =, and quotes survive a round-trip" {
  v='a "quoted" = value'
  run bash -c "source '$CFG'; config_set tricky 'a \"quoted\" = value'; config_get tricky"
  [ "$status" -eq 0 ]
  [ "$output" = "$v" ]
}

@test "TC-A-18-03b: config_set updates an existing key in place (no duplicate)" {
  run bash -c "source '$CFG'; config_set region amazon.com; config_set region amazon.de; config_get region; grep -c '^region' '$CONFFILE'"
  [ "${lines[0]}" = "amazon.de" ]
  [ "${lines[1]}" = "1" ]
}

@test "TC-A-19-01: precedence flag > env > file" {
  printf 'region = "amazon.com"\n' > "$CONFFILE"
  run bash -c "source '$CFG'; ALEXA_REGION=amazon.de config_resolve region amazon.in ALEXA_REGION"
  [ "$output" = "amazon.in" ]
}

@test "TC-A-19-02: precedence env > file when no flag" {
  printf 'region = "amazon.com"\n' > "$CONFFILE"
  run bash -c "source '$CFG'; ALEXA_REGION=amazon.de config_resolve region '' ALEXA_REGION"
  [ "$output" = "amazon.de" ]
}

@test "TC-A-19-03: precedence file when no flag/env" {
  printf 'region = "amazon.com"\n' > "$CONFFILE"
  run bash -c "source '$CFG'; config_resolve region '' ALEXA_REGION"
  [ "$output" = "amazon.com" ]
}
