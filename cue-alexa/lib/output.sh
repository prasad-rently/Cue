# output.sh — output formatters for cue-alexa (CUE-A-21 / FR-041..043).
# Sourced by bin/cue-alexa. Honours three orthogonal modes set via out_init:
#   json    : emit machine-readable JSON results instead of human text
#   quiet   : suppress informational stdout (errors still go to stderr)
#   verbose : emit debug lines to stderr
# shellcheck shell=bash

# out_init <json:0|1> <quiet:0|1> <verbose:0|1>
out_init() {
  OUTPUT_JSON="${1:-0}"
  OUTPUT_QUIET="${2:-0}"
  OUTPUT_VERBOSE="${3:-0}"
}

# out_info <msg...> — human-readable informational line on stdout.
# Suppressed under --quiet, and under --json (where the result payload is the output).
out_info() {
  [[ "${OUTPUT_QUIET:-0}" == 1 ]] && return 0
  [[ "${OUTPUT_JSON:-0}" == 1 ]] && return 0
  printf '%s\n' "$*"
}

# out_error <msg...> — error line on stderr. Always emitted (not suppressed by --quiet).
out_error() {
  printf 'cue-alexa: error: %s\n' "$*" >&2
}

# out_debug <msg...> — debug line on stderr, only under --verbose.
out_debug() {
  [[ "${OUTPUT_VERBOSE:-0}" == 1 ]] || return 0
  printf 'cue-alexa: debug: %s\n' "$*" >&2
}

# json_escape <str> — emit <str> as a JSON-encoded string (quoted, fully escaped).
json_escape() {
  jq -n --arg s "$1" '$s'
}

# emit_result <human-text> <json-payload> — mode-aware result emission.
# In --json mode prints the JSON payload (always, even under --quiet, since it IS
# the result). Otherwise prints the human text unless --quiet.
emit_result() {
  local human="$1" json="$2"
  if [[ "${OUTPUT_JSON:-0}" == 1 ]]; then
    printf '%s\n' "$json"
  else
    [[ "${OUTPUT_QUIET:-0}" == 1 ]] && return 0
    printf '%s\n' "$human"
  fi
}
