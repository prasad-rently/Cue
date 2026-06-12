# bash completion for cue-google.
# shellcheck shell=bash
_cue_google() {
  local cur prev subs flags
  cur="${COMP_WORDS[COMP_CWORD]}"; prev="${COMP_WORDS[COMP_CWORD-1]}"
  subs="setup login doctor device-model device config"
  flags="--json --quiet --device-id --device-model --version --help --cue-engine-info --reset-venv"
  if [[ "$COMP_CWORD" -eq 1 ]]; then
    # shellcheck disable=SC2207
    COMPREPLY=( $(compgen -W "$subs $flags" -- "$cur") ); return 0
  fi
  case "$prev" in
    doctor) # shellcheck disable=SC2207
            COMPREPLY=( $(compgen -W "--json --offline" -- "$cur") ); return 0 ;;
    config) # shellcheck disable=SC2207
            COMPREPLY=( $(compgen -W "get set" -- "$cur") ); return 0 ;;
    device-model|device) # shellcheck disable=SC2207
            COMPREPLY=( $(compgen -W "register list delete" -- "$cur") ); return 0 ;;
  esac
}
complete -F _cue_google cue-google
