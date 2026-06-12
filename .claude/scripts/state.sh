#!/usr/bin/env bash
# state.sh — read/update the phased-build execution state.
# Thin jq wrapper over .claude/state/execution-state.json so both humans and
# build-agents mutate state the same way (avoids hand-editing JSON + drift).
#
# Usage:
#   state.sh status [component]            # print progress table (all, or one component)
#   state.sh next                          # print the next actionable step across components
#   state.sh set <component> <step> <status> [note]
#                                          # status ∈ todo|in_progress|blocked|done
#   state.sh active <component> <step>     # mark what's currently being worked on
#
# Examples:
#   .claude/scripts/state.sh status cue-alexa
#   .claude/scripts/state.sh set cue-alexa EP-1 done "skeleton + README + commit landed"
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE="$ROOT/.claude/state/execution-state.json"
TODAY="$(date +%F)"

command -v jq >/dev/null || { echo "state.sh needs jq (brew install jq)" >&2; exit 2; }
[ -f "$STATE" ] || { echo "missing $STATE" >&2; exit 2; }

steps_path() { # echo the jq path holding a component's steps map
  case "$1" in
    cue) echo '.phases' ;;
    *)   echo '.execution_prompts' ;;
  esac
}

cmd_status() {
  local filter="${1:-}"
  jq -r --arg only "$filter" '
    .components | to_entries[]
    | select($only == "" or .key == $only)
    | .key as $c
    | (.value.phases // .value.execution_prompts) as $steps
    | "\n## \($c)  (current: \(.value.current // "-"))",
      ($steps | to_entries[]
        | "  [\(.value.status | ascii_upcase[0:4])] \(.key)  \(.value.title)")
  ' "$STATE"
}

cmd_next() {
  jq -r '
    .components | to_entries[]
    | .key as $c
    | (.value.phases // .value.execution_prompts) as $steps
    | ($steps | to_entries
        | map(select(.value.status == "in_progress")) + map(select(.value.status == "todo"))
        | .[0]) as $n
    | select($n != null)
    | "\($c): \($n.key) — \($n.value.title)  [\($n.value.status)]"
  ' "$STATE"
}

cmd_set() {
  local comp="$1" step="$2" status="$3" note="${4:-}"
  case "$status" in todo|in_progress|blocked|done) ;; *)
    echo "status must be todo|in_progress|blocked|done" >&2; exit 2 ;; esac
  local sp; sp="$(steps_path "$comp")"
  local tmp; tmp="$(mktemp)"
  jq --arg c "$comp" --arg s "$step" --arg st "$status" --arg n "$note" --arg d "$TODAY" \
    ".components[\$c]${sp}[\$s].status = \$st
     | (if \$n != \"\" then .components[\$c]${sp}[\$s].notes = \$n else . end)
     | ._meta.updated = \$d" "$STATE" > "$tmp" && mv "$tmp" "$STATE"
  echo "set $comp/$step -> $status"
}

cmd_active() {
  local comp="$1" step="$2" tmp; tmp="$(mktemp)"
  jq --arg c "$comp" --arg s "$step" --arg d "$TODAY" \
    '._meta.active_component = $c | ._meta.active_step = $s
     | .components[$c].current = $s | ._meta.updated = $d' "$STATE" > "$tmp" && mv "$tmp" "$STATE"
  echo "active -> $comp/$step"
}

case "${1:-status}" in
  status) shift; cmd_status "${1:-}" ;;
  next)   cmd_next ;;
  set)    shift; cmd_set "$@" ;;
  active) shift; cmd_active "$@" ;;
  *) echo "usage: state.sh {status [component]|next|set <c> <step> <status> [note]|active <c> <step>}" >&2; exit 2 ;;
esac
