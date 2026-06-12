# discover.sh — find cue-* engines on PATH via the discovery contract (README §5).
# An engine is any executable `cue-<vendor>` on PATH that returns a JSON descriptor
# (with a .name field) from `--cue-engine-info`. Invalid responders are skipped.
# shellcheck shell=bash

# discover_engines — prints one "<vendor>\t<path>" line per discovered engine.
discover_engines() {
  local -A seen=()
  local dir bin base name info
  local IFS=':'
  local -a dirs
  read -ra dirs <<<"$PATH"
  for dir in "${dirs[@]}"; do
    [[ -d "$dir" ]] || continue
    for bin in "$dir"/cue-*; do
      [[ -x "$bin" && -f "$bin" ]] || continue
      base="${bin##*/}"
      name="${base#cue-}"
      [[ -n "${seen[$name]:-}" ]] && continue          # first on PATH wins
      info="$("$bin" --cue-engine-info 2>/dev/null)" || continue
      printf '%s' "$info" | jq -e 'has("name")' >/dev/null 2>&1 || continue
      seen[$name]=1
      printf '%s\t%s\n' "$name" "$bin"
    done
  done
}

# engine_path <vendor> — print the path of a discovered engine, or return 1.
engine_path() {
  local vendor="$1" name path
  while IFS=$'\t' read -r name path; do
    [[ "$name" == "$vendor" ]] && { printf '%s\n' "$path"; return 0; }
  done < <(discover_engines)
  return 1
}

# engine_count — number of discovered engines.
engine_count() { discover_engines | grep -c . || true; }
