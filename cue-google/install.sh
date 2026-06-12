#!/usr/bin/env bash
# install.sh — install cue-google (CUE-G-24 / FR-061). No sudo required.
#
# From a checked-out repo:   ./install.sh
# Custom prefix:             PREFIX="$HOME/.local" ./install.sh
#
# Installs the engine tree to <prefix>/libexec/cue-google and a launcher at
# <prefix>/bin/cue-google. The internal Python venv is bootstrapped lazily on the
# first command that needs it (see lib/python_bridge.sh).
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

err()  { printf 'install: error: %s\n' "$*" >&2; exit 1; }
info() { printf 'install: %s\n' "$*"; }

if [[ -z "${BASH_VERSINFO:-}" || "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  err "bash 4+ required (found ${BASH_VERSION:-unknown}). macOS: brew install bash"
fi
command -v jq >/dev/null 2>&1 || err "jq is required (brew install jq / apt-get install jq)"

# Python 3.10+ check up front (FR-061 acceptance).
_py=""
for p in python3.13 python3.12 python3.11 python3.10 python3; do
  if command -v "$p" >/dev/null 2>&1 && \
     "$p" -c 'import sys; raise SystemExit(0 if sys.version_info[:2] >= (3,10) else 1)' 2>/dev/null; then
    _py="$p"; break
  fi
done
[[ -n "$_py" ]] || err "Python 3.10+ is required but was not found. macOS: brew install python"
info "using $($_py --version)"

PREFIX="${PREFIX:-/usr/local}"
if ! mkdir -p "$PREFIX/bin" 2>/dev/null || [[ ! -w "$PREFIX/bin" ]]; then
  PREFIX="$HOME/.local"
  info "falling back to PREFIX=$PREFIX (no write access to /usr/local)"
  mkdir -p "$PREFIX/bin"
fi

LIBEXEC="$PREFIX/libexec/cue-google"
BIN="$PREFIX/bin/cue-google"

info "installing to $LIBEXEC"
rm -rf "$LIBEXEC"; mkdir -p "$LIBEXEC"
cp -R "$SRC_DIR/bin" "$SRC_DIR/lib" "$SRC_DIR/pysrc" \
      "$SRC_DIR/requirements.lock" "$SRC_DIR/VERSION" "$LIBEXEC/"
chmod +x "$LIBEXEC/bin/cue-google"

cat > "$BIN" <<EOF
#!/usr/bin/env bash
exec "$LIBEXEC/bin/cue-google" "\$@"
EOF
chmod +x "$BIN"

# completions (best-effort)
comp_bash="$PREFIX/share/bash-completion/completions"
comp_zsh="$PREFIX/share/zsh/site-functions"
mkdir -p "$comp_bash" "$comp_zsh" 2>/dev/null || true
cp "$SRC_DIR/share/completions/cue-google.bash" "$comp_bash/cue-google" 2>/dev/null || true
cp "$SRC_DIR/share/completions/_cue-google"      "$comp_zsh/_cue-google"  2>/dev/null || true

ver="$("$BIN" --version)"
info "installed cue-google $ver -> $BIN"
case ":$PATH:" in
  *":$PREFIX/bin:"*) ;;
  *) info "add to PATH:  export PATH=\"$PREFIX/bin:\$PATH\"" ;;
esac
info "verify now (no venv needed): cue-google --version && cue-google --cue-engine-info"
info "next: cue-google setup   (the internal Python venv builds on first command that needs it)"
