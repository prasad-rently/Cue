# errors.sh — exit-code constants (CUE_ALEXA_EXECUTION_PLAN.md §10) + die() helper.
# Sourced by bin/cue-alexa and other libs. Not executable on its own.
# shellcheck shell=bash

# Idempotent source guard: re-sourcing must not re-run `readonly` (which would error).
# Constants are consumed by sibling libs/bin via `source`, so SC2034 (unused) is expected.
# shellcheck disable=SC2034
if [[ -z "${_CUE_ALEXA_ERRORS_SOURCED:-}" ]]; then
  _CUE_ALEXA_ERRORS_SOURCED=1

  readonly E_OK=0                 # success
  readonly E_FAIL=1               # generic failure
  readonly E_USAGE=2              # invalid usage (bad flags, missing args)
  readonly E_AUTH=10              # auth expired or missing
  readonly E_AUTH_REFRESH=11      # auth refresh failed
  readonly E_DEVICE_NOT_FOUND=20  # device not found
  readonly E_DEVICE_OFFLINE=21    # device offline
  readonly E_UPSTREAM=30          # upstream call returned an error
  readonly E_UPSTREAM_PARSE=31    # upstream returned unparseable response
  readonly E_NETWORK=40           # network error
  readonly E_RATELIMIT=41         # Amazon rate-limit (429)
  readonly E_NOTIMPL=99           # not yet implemented (development only)
fi

# die <code> <message...> — emit a greppable error on stderr and exit with <code>.
# Never writes to stdout (keeps --json/--quiet output clean).
die() {
  local code="${1:-1}"
  shift || true
  printf 'cue-alexa: error: %s\n' "$*" >&2
  exit "$code"
}
