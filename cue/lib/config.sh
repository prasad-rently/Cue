# config.sh — umbrella config: default_vendor + [devices] map (CUE_README.md §6).
# ${XDG_CONFIG_HOME:-~/.config}/cue/config.toml
# shellcheck shell=bash

cue_config_dir()  { printf '%s/cue\n' "${XDG_CONFIG_HOME:-$HOME/.config}"; }
cue_config_file() { printf '%s/config.toml\n' "$(cue_config_dir)"; }

_cue_trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}
_cue_unquote() { local s="$1"; s="${s#\"}"; s="${s%\"}"; printf '%s' "$s"; }

# cue_config_get <key> — read a top-level (pre-section) key. Returns 1 if absent.
cue_config_get() {
  local key="$1" file line val
  file="$(cue_config_file)"; [[ -f "$file" ]] || return 1
  while IFS= read -r line; do
    case "$line" in \[*\]*) break ;; esac   # stop at first section
    [[ "$line" == *=* ]] || continue
    [[ "$(_cue_trim "${line%%=*}")" == "$key" ]] || continue
    val="$(_cue_trim "${line#*=}")"; _cue_unquote "$val"; printf '\n'; return 0
  done < "$file"
  return 1
}

# cue_device_vendor <device-name> — look up the vendor mapped to a device in [devices].
cue_device_vendor() {
  local name="$1" file line in_dev=0 key val
  file="$(cue_config_file)"; [[ -f "$file" ]] || return 1
  while IFS= read -r line; do
    case "$(_cue_trim "$line")" in
      "[devices]") in_dev=1; continue ;;
      "["*"]")     in_dev=0; continue ;;
    esac
    (( in_dev )) || continue
    [[ "$line" == *=* ]] || continue
    key="$(_cue_unquote "$(_cue_trim "${line%%=*}")")"
    val="$(_cue_unquote "$(_cue_trim "${line#*=}")")"
    [[ "$key" == "$name" ]] && { printf '%s\n' "$val"; return 0; }
  done < "$file"
  return 1
}
