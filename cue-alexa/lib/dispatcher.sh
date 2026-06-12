# dispatcher.sh — the ONLY layer coupled to the vendored upstream (AGENT_RULES §5).
# Routes a mode {text|speak|routine} + device target to alexa_remote_control.sh and
# maps its result to documented exit codes. CUE-A-06/07/08/12/13, FR-010..018.
# Depends on lib/errors.sh and lib/output.sh.
# shellcheck shell=bash

# cue_alexa_upstream — path to the upstream script. Overridable via env for tests.
cue_alexa_upstream() {
  if [[ -n "${CUE_ALEXA_UPSTREAM:-}" ]]; then
    printf '%s\n' "$CUE_ALEXA_UPSTREAM"; return 0
  fi
  local libdir
  libdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  printf '%s/../vendor/alexa_remote_control.sh\n' "$libdir"
}

# dispatch <mode> <target> [target-value] <text>
#   mode   : text | speak | routine
#   target : --device <name> | --all | --group <name>
# All user text is passed to the upstream as a single, unexpanded argument.
dispatch() {
  local mode="${1:-}"; shift || true

  local device="" group="" all=0
  case "${1:-}" in
    --device) device="${2:-}"; shift 2 || true ;;
    --all)    all=1; shift || true ;;
    --group)  group="${2:-}"; shift 2 || true ;;
  esac
  local text="${1:-}"

  local directive
  case "$mode" in
    text)    directive="textcommand:" ;;
    speak)   directive="speak:" ;;
    routine) directive="automation:" ;;
    *) die "$E_USAGE" "invalid mode: ${mode:-<none>} (expected text|speak|routine)" ;;
  esac
  [[ -n "$text" ]] || die "$E_USAGE" "empty command text"

  # Build the upstream argv as an array — never as a string — so nothing is re-parsed.
  local -a uargs=()
  if (( all )); then
    uargs+=(-d "ALL")
  elif [[ -n "$device" ]]; then
    uargs+=(-d "$device")
  elif [[ -n "$group" ]]; then
    uargs+=(-d "$group")
  fi
  uargs+=(-e "${directive}${text}")

  local up out rc=0
  up="$(cue_alexa_upstream)"
  out="$("$up" "${uargs[@]}")" || rc=$?
  if (( rc != 0 )); then
    die "$E_UPSTREAM" "upstream command failed (exit $rc)"
  fi

  emit_result "ok: ${mode} command sent" \
    "$(jq -n --arg s ok --arg m "$mode" --arg t "$text" \
       --argjson r "$(jq -Rs . <<<"$out")" \
       '{status:$s, mode:$m, text:$t, response:$r}')"
}

# upstream_devices — list device names (one per line) via the upstream `-a` flag.
# Dies E_UPSTREAM on failure. This is the only place that calls upstream for discovery.
upstream_devices() {
  local up out rc=0
  up="$(cue_alexa_upstream)"
  out="$("$up" -a)" || rc=$?
  (( rc == 0 )) || die "$E_UPSTREAM" "device list failed (exit $rc)"
  printf '%s\n' "$out"
}
