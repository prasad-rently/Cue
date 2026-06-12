#!/usr/bin/env bats
# Tests for lib/auth.sh — CUE-A-01/02/03 (auth + secure storage).
# TC-A-02-01, TC-A-02-02, TC-A-03-01, plus credential-flow and auth_status. TDD red.

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  LIBS="source '$REPO_ROOT/lib/errors.sh'; source '$REPO_ROOT/lib/config.sh'; source '$REPO_ROOT/lib/auth.sh'"
  export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/cfg"
  ADIR="$XDG_CONFIG_HOME/cue/alexa"
  COOKIE_FIXTURE="$REPO_ROOT/tests/fixtures/mock-amazon/cookie.txt"
}

@test "TC-A-02-01: auth_login_cookie copies a valid Netscape cookie to 0600" {
  run bash -c "$LIBS; auth_login_cookie '$COOKIE_FIXTURE'"
  [ "$status" -eq 0 ]
  [ -f "$ADIR/cookie.txt" ]
  [ "$(stat -f '%Lp' "$ADIR/cookie.txt")" = "600" ]
  diff "$COOKIE_FIXTURE" "$ADIR/cookie.txt"
}

@test "TC-A-03-01: cookie import creates the config dir 0700" {
  run bash -c "$LIBS; auth_login_cookie '$COOKIE_FIXTURE'"
  [ "$status" -eq 0 ]
  [ "$(stat -f '%Lp' "$ADIR")" = "700" ]
}

@test "TC-A-02-02: malformed cookie file is rejected with E_AUTH (10), not stored" {
  bad="$BATS_TEST_TMPDIR/bad.txt"
  printf 'this is not a cookie file\n' > "$bad"
  run bash -c "$LIBS; auth_login_cookie '$bad'"
  [ "$status" -eq 10 ]
  [ ! -f "$ADIR/cookie.txt" ]
}

@test "TC-A-02-03: missing cookie path is rejected with E_AUTH (10)" {
  run bash -c "$LIBS; auth_login_cookie '$BATS_TEST_TMPDIR/nope.txt'"
  [ "$status" -eq 10 ]
}

@test "TC-A-01-01: credential flow stores email/password/totp at 0600 and never echoes the password to stdout" {
  run --separate-stderr bash -c "printf 'me@example.com\nhunter2\nJBSWY3DPEHPK3PXP\n' | { $LIBS; auth_login_credentials; }"
  [ "$status" -eq 0 ]
  [ -f "$ADIR/credentials" ]
  [ "$(stat -f '%Lp' "$ADIR/credentials")" = "600" ]
  # secret must not leak to stdout
  [[ "$output" != *"hunter2"* ]]
  # but must be persisted to the (secured) creds file
  grep -q 'hunter2' "$ADIR/credentials"
  grep -q 'me@example.com' "$ADIR/credentials"
}

@test "TC-A-AUTH-status: auth_status is non-zero with no creds, zero after cookie import" {
  run bash -c "$LIBS; auth_status"
  [ "$status" -ne 0 ]
  run bash -c "$LIBS; auth_login_cookie '$COOKIE_FIXTURE'; auth_status"
  [ "$status" -eq 0 ]
}
