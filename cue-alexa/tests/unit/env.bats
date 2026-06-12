#!/usr/bin/env bats
# Regression tests for setup_upstream_env (bin/cue-alexa) — the auth→upstream
# wiring. Guards against the `set -e` abort bug where a trailing falsey
# `[[ ... ]] &&` made the function return non-zero and killed real commands
# (speak/text) before dispatch. bin/cue-alexa is sourceable (main is guarded).

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  CLI="$REPO_ROOT/bin/cue-alexa"
  export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/cfg"
  mkdir -p "$XDG_CONFIG_HOME/cue/alexa"
  # ensure the real (non-mock) path runs
  unset CUE_ALEXA_UPSTREAM
}

@test "sourcing bin/cue-alexa does not run main" {
  run bash -c "source '$CLI'; echo SOURCED_OK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SOURCED_OK"* ]]
  [[ "$output" != *"USAGE"* ]]
}

@test "setup_upstream_env returns 0 with NO refresh token under set -e (regression)" {
  run bash -c "set -euo pipefail; source '$CLI'; setup_upstream_env; echo rc=\$?"
  [ "$status" -eq 0 ]
  [[ "$output" == *"rc=0"* ]]
}

@test "setup_upstream_env exports domains and materialises the cookie for the upstream" {
  printf '# Netscape HTTP Cookie File\n.amazon.com\tTRUE\t/\tTRUE\t1799999999\tsession-id\t1\n' \
    > "$XDG_CONFIG_HOME/cue/alexa/cookie.txt"
  run bash -c "set -euo pipefail; source '$CLI'; setup_upstream_env; printf '%s|%s\n' \"\$AMAZON\" \"\$ALEXA\"; test -f \"\$TMP/.alexa.cookie\" && echo COOKIE_OK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"amazon.com|alexa.amazon.com"* ]]
  [[ "$output" == *"COOKIE_OK"* ]]
}

@test "setup_upstream_env honours a configured region" {
  printf 'region = "amazon.in"\n' > "$XDG_CONFIG_HOME/cue/alexa/config.toml"
  run bash -c "set -euo pipefail; source '$CLI'; setup_upstream_env; printf '%s|%s\n' \"\$AMAZON\" \"\$ALEXA\""
  [ "$status" -eq 0 ]
  [[ "$output" == *"amazon.in|alexa.amazon.in"* ]]
}

@test "TTS_LOCALE defaults from region, not the upstream's de-DE" {
  run bash -c "set -euo pipefail; source '$CLI'; setup_upstream_env; echo \"\$TTS_LOCALE\""
  [ "$status" -eq 0 ]
  [[ "$output" == *"en-US"* ]]   # amazon.com default
}

@test "TTS_LOCALE derives en-IN for amazon.in" {
  printf 'region = "amazon.in"\n' > "$XDG_CONFIG_HOME/cue/alexa/config.toml"
  run bash -c "set -euo pipefail; source '$CLI'; setup_upstream_env; echo \"\$TTS_LOCALE\""
  [[ "$output" == *"en-IN"* ]]
}

@test "explicit locale config overrides the region default" {
  printf 'region = "amazon.com"\nlocale = "en-GB"\n' > "$XDG_CONFIG_HOME/cue/alexa/config.toml"
  run bash -c "set -euo pipefail; source '$CLI'; setup_upstream_env; echo \"\$TTS_LOCALE\""
  [[ "$output" == *"en-GB"* ]]
}
