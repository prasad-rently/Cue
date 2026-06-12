# route.sh — exit codes + routing helpers for the umbrella (CUE_README.md §4).
# Depends on lib/discover.sh and lib/config.sh.
# shellcheck shell=bash

# Constants consumed by bin/cue via source, so SC2034 (unused here) is expected.
# shellcheck disable=SC2034
readonly CUE_E_OK=0
readonly CUE_E_USAGE=2
readonly CUE_E_NO_ENGINE=3

cue_die() { printf 'cue: error: %s\n' "$2" >&2; exit "$1"; }

# route_to <vendor> <args...> — exec the engine, surfacing its exit code (§5).
route_to() {
  local vendor="$1"; shift
  local path
  path="$(engine_path "$vendor")" || cue_die "$CUE_E_NO_ENGINE" \
    "engine not installed: cue-$vendor (not found on PATH)"
  exec "$path" "$@"
}

# _arg_device <args...> — echo the value following a --device flag, if present.
_arg_device() {
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == "--device" ]]; then printf '%s' "${2:-}"; return 0; fi
    shift
  done
  return 1
}

# resolve_and_route <args...> — precedence chain steps 3–6 (no explicit flag/subcmd).
resolve_and_route() {
  # 3. per-device routing
  local device vendor
  if device="$(_arg_device "$@")" && [[ -n "$device" ]]; then
    if vendor="$(cue_device_vendor "$device")" && [[ -n "$vendor" ]]; then
      route_to "$vendor" "$@"; return
    fi
  fi
  # 4. default vendor (env then config)
  vendor="${CUE_DEFAULT:-}"
  [[ -n "$vendor" ]] || vendor="$(cue_config_get default_vendor 2>/dev/null || true)"
  if [[ -n "$vendor" ]]; then route_to "$vendor" "$@"; return; fi
  # 5. single-engine fallback
  local engines count only
  engines="$(discover_engines)"
  count="$(printf '%s\n' "$engines" | grep -c . || true)"
  if [[ "$count" == "1" ]]; then
    only="$(printf '%s\n' "$engines" | head -n1 | cut -f1)"
    route_to "$only" "$@"; return
  fi
  # 6. prompt / error
  if [[ "$count" == "0" ]]; then
    cue_die "$CUE_E_NO_ENGINE" "no engines installed (looked for cue-* on PATH)"
  fi
  cue_prompt_route "$@"
}

# cue_prompt_route — interactive vendor selection when ambiguous (CUE-U-10).
cue_prompt_route() {
  if [[ ! -t 0 ]]; then
    cue_die "$CUE_E_USAGE" "multiple engines installed; pass --alexa/--google or set default_vendor"
  fi
  local engines names choice
  engines="$(discover_engines)"
  names="$(printf '%s\n' "$engines" | cut -f1 | paste -sd'/' -)"
  printf 'Which engine? [%s]: ' "$names" >&2
  IFS= read -r choice
  [[ -n "$choice" ]] || cue_die "$CUE_E_USAGE" "no engine chosen"
  route_to "$choice" "$@"
}
