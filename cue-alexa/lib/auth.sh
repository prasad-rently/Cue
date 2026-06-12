# auth.sh — authentication for cue-alexa (CUE-A-01/02/03, FR-001..007).
# Two flows: credential+TOTP and Netscape cookie capture. Secrets are stored only
# under the config dir (0700) with files at 0600, and are never written to stdout.
# Depends on lib/errors.sh (E_AUTH, die) and lib/config.sh (cue_alexa_config_dir).
# shellcheck shell=bash

auth_cookie_file() { printf '%s/cookie.txt\n' "$(cue_alexa_config_dir)"; }
auth_creds_file()  { printf '%s/credentials\n' "$(cue_alexa_config_dir)"; }

_auth_ensure_dir() {
  local dir; dir="$(cue_alexa_config_dir)"
  mkdir -p "$dir"; chmod 0700 "$dir"
}

# _auth_looks_like_cookie <file> — heuristic Netscape-cookie validation.
# Accept if it has the Netscape header OR any tab-delimited 7-field line.
_auth_looks_like_cookie() {
  local f="$1"
  [[ -f "$f" && -s "$f" ]] || return 1
  head -n1 "$f" | grep -qi 'Netscape HTTP Cookie File' && return 0
  # a real cookie line has 7 tab-separated fields
  awk -F'\t' 'NF>=7 {found=1} END{exit found?0:1}' "$f"
}

# auth_login_cookie <path> — validate + copy a Netscape cookie into the config dir.
auth_login_cookie() {
  local src="${1:-}"
  [[ -n "$src" && -f "$src" ]] || die "$E_AUTH" "cookie file not found: ${src:-<none>}"
  _auth_looks_like_cookie "$src" || die "$E_AUTH" "not a Netscape-format cookie file: $src"
  _auth_ensure_dir
  local dest; dest="$(auth_cookie_file)"
  cp "$src" "$dest"
  chmod 0600 "$dest"
}

# auth_login_credentials — interactively capture email/password/TOTP secret.
# Prompts go to stderr; nothing sensitive is printed to stdout.
auth_login_credentials() {
  local email password totp
  printf 'Amazon email: ' >&2;        IFS= read -r email
  printf 'Amazon password: ' >&2;     IFS= read -r password
  printf 'TOTP secret (blank if none): ' >&2; IFS= read -r totp
  _auth_ensure_dir
  local f; f="$(auth_creds_file)"
  : > "$f"; chmod 0600 "$f"
  {
    printf 'EMAIL=%s\n' "$email"
    printf 'PASSWORD=%s\n' "$password"
    printf 'MFA_SECRET=%s\n' "$totp"
  } > "$f"
  chmod 0600 "$f"
}

# auth_status — 0 if usable auth state exists (cookie or credentials), else non-zero.
auth_status() {
  local cookie creds
  cookie="$(auth_cookie_file)"; creds="$(auth_creds_file)"
  [[ -s "$cookie" || -s "$creds" ]]
}
