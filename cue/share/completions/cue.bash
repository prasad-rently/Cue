# bash completion for cue (P5). Install: source this file, or drop it in
# $(brew --prefix)/etc/bash_completion.d/  (Homebrew installs it automatically).
# shellcheck shell=bash

_cue() {
  local cur prev subcommands flags
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  subcommands="engines doctor alexa google"
  flags="--alexa --google --both --version --help"

  # First word: subcommands or top-level flags.
  if [[ "$COMP_CWORD" -eq 1 ]]; then
    # SC2207: word-splitting compgen output is the documented idiom here.
    # shellcheck disable=SC2207
    COMPREPLY=( $(compgen -W "$subcommands $flags" -- "$cur") )
    return 0
  fi

  # Second word after engines/doctor: their --json flag.
  case "$prev" in
    engines|doctor)
      # shellcheck disable=SC2207
      COMPREPLY=( $(compgen -W "--json" -- "$cur") )
      return 0
      ;;
  esac
  # Past a vendor selection, defer to the engine (cue forwards verbatim).
  return 0
}
complete -F _cue cue
