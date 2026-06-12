# config.sh — TOML config read/write for cue-alexa (CUE-A-18/19, FR-030..033).
# Minimal flat-key TOML: `key = "value"` lines. Sections ([x]) are ignored.
# Config root honours XDG: ${XDG_CONFIG_HOME:-~/.config}/cue/alexa/config.toml.
# shellcheck shell=bash

cue_alexa_config_dir()  { printf '%s/cue/alexa\n' "${XDG_CONFIG_HOME:-$HOME/.config}"; }
cue_alexa_config_file() { printf '%s/config.toml\n' "$(cue_alexa_config_dir)"; }

# _config_trim <str> — strip leading/trailing whitespace.
_config_trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# config_get <key> -> prints value (unquoted, unescaped). Returns 1 if absent.
config_get() {
  local key="$1" file line val
  file="$(cue_alexa_config_file)"
  [[ -f "$file" ]] || return 1
  line="$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$file" | head -n1)" || return 1
  [[ -n "$line" ]] || return 1
  val="$(_config_trim "${line#*=}")"
  # Strip one layer of surrounding double quotes and unescape \" and \\.
  if [[ "$val" == \"*\" ]]; then
    val="${val#\"}"; val="${val%\"}"
    val="${val//\\\"/\"}"; val="${val//\\\\/\\}"
  fi
  printf '%s\n' "$val"
}

# config_set <key> <value> — create/refresh config.toml with secure perms.
config_set() {
  local key="$1" value="$2" dir file esc tmp
  dir="$(cue_alexa_config_dir)"; file="$(cue_alexa_config_file)"
  mkdir -p "$dir"; chmod 0700 "$dir"
  [[ -f "$file" ]] || : > "$file"
  chmod 0600 "$file"
  # Escape for a TOML basic string: backslash first, then double-quote.
  esc="${value//\\/\\\\}"; esc="${esc//\"/\\\"}"
  if grep -qE "^[[:space:]]*${key}[[:space:]]*=" "$file"; then
    tmp="$(mktemp)"
    awk -v k="$key" -v v="\"$esc\"" '
      $0 ~ ("^[[:space:]]*" k "[[:space:]]*=") && !seen { print k " = " v; seen=1; next }
      { print }
    ' "$file" > "$tmp" && mv "$tmp" "$file"
    chmod 0600 "$file"
  else
    printf '%s = "%s"\n' "$key" "$esc" >> "$file"
  fi
}

# config_resolve <key> <flag-value> <env-var-name> — precedence flag > env > file.
config_resolve() {
  local key="$1" flagval="${2:-}" envname="${3:-}"
  if [[ -n "$flagval" ]]; then printf '%s\n' "$flagval"; return 0; fi
  if [[ -n "$envname" && -n "${!envname:-}" ]]; then printf '%s\n' "${!envname}"; return 0; fi
  # Best-effort: a missing key yields empty output, not a failure (safe under set -e).
  config_get "$key" || return 0
}
