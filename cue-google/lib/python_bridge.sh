# python_bridge.sh — manage the engine's internal Python venv (CUE-G-21 / FR-062).
# The user never manages Python: the venv lives at
# ${XDG_CONFIG_HOME:-~/.config}/cue/google/.venv and is created + populated from
# requirements.lock on first use. Requires CG_REPO_DIR (set by bin/cue-google).
# shellcheck shell=bash

cue_google_state_dir() { printf '%s/cue/google\n' "${XDG_CONFIG_HOME:-$HOME/.config}"; }
cue_google_venv_dir()  { printf '%s/.venv\n' "$(cue_google_state_dir)"; }

# _cg_find_python — echo a python>=3.10 interpreter on PATH, or return 1.
_cg_find_python() {
  local p
  for p in python3.13 python3.12 python3.11 python3.10 python3; do
    command -v "$p" >/dev/null 2>&1 || continue
    if "$p" -c 'import sys; raise SystemExit(0 if sys.version_info[:2] >= (3,10) else 1)' 2>/dev/null; then
      printf '%s\n' "$p"; return 0
    fi
  done
  return 1
}

# python_bridge_ensure — create the venv + install deps once (idempotent via marker).
python_bridge_ensure() {
  local venv marker py
  venv="$(cue_google_venv_dir)"
  marker="$venv/.deps-installed"
  [[ -f "$marker" ]] && return 0

  py="$(_cg_find_python)" || {
    printf 'cue-google: error: Python 3.10+ is required but was not found. macOS: brew install python\n' >&2
    return 2
  }
  if [[ ! -d "$venv" ]]; then
    mkdir -p "$(dirname "$venv")"
    "$py" -m venv "$venv" || { printf 'cue-google: error: failed to create venv at %s\n' "$venv" >&2; return 1; }
  fi
  "$venv/bin/python" -m pip install --quiet --upgrade pip >/dev/null 2>&1 || true
  if ! "$venv/bin/python" -m pip install --quiet -r "$CG_REPO_DIR/requirements.lock" >&2; then
    printf 'cue-google: error: dependency install failed (see above)\n' >&2
    return 1
  fi
  touch "$marker"
}

# python_call <module> [args...] — run cue_google.<module> inside the venv.
python_call() {
  local module="$1"; shift
  python_bridge_ensure || exit $?
  PYTHONPATH="$CG_REPO_DIR/pysrc${PYTHONPATH:+:$PYTHONPATH}" \
    "$(cue_google_venv_dir)/bin/python" -m "cue_google.$module" "$@"
}

# python_bridge_reset — nuke the venv so the next call rebuilds it (--reset-venv).
python_bridge_reset() {
  rm -rf "$(cue_google_venv_dir)"
}
