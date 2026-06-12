#!/usr/bin/env bash
# install.sh — install the `cue` umbrella router (P4). No sudo required.
#
# From a checked-out repo:   ./install.sh
# Custom prefix:             PREFIX="$HOME/.local" ./install.sh
#
# Installs the router tree to <prefix>/libexec/cue and a launcher at
# <prefix>/bin/cue. Falls back to $HOME/.local if <prefix> isn't writable.
# Engines (cue-alexa, cue-google) install separately; cue discovers them on PATH.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

err()  { printf 'install: error: %s\n' "$*" >&2; exit 1; }
info() { printf 'install: %s\n' "$*"; }

if [[ -z "${BASH_VERSINFO:-}" || "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  err "bash 4+ required (found ${BASH_VERSION:-unknown}). macOS: brew install bash"
fi
command -v jq >/dev/null 2>&1 || err "jq is required (brew install jq / apt-get install jq)"

PREFIX="${PREFIX:-/usr/local}"
if ! mkdir -p "$PREFIX/bin" 2>/dev/null || [[ ! -w "$PREFIX/bin" ]]; then
  PREFIX="$HOME/.local"
  info "falling back to PREFIX=$PREFIX (no write access to /usr/local)"
  mkdir -p "$PREFIX/bin"
fi

LIBEXEC="$PREFIX/libexec/cue"
BIN="$PREFIX/bin/cue"

info "installing to $LIBEXEC"
rm -rf "$LIBEXEC"; mkdir -p "$LIBEXEC"
cp -R "$SRC_DIR/bin" "$SRC_DIR/lib" "$SRC_DIR/VERSION" "$LIBEXEC/"
chmod +x "$LIBEXEC/bin/cue"

cat > "$BIN" <<EOF
#!/usr/bin/env bash
exec "$LIBEXEC/bin/cue" "\$@"
EOF
chmod +x "$BIN"

# completions (best-effort, non-fatal)
comp_bash="$PREFIX/share/bash-completion/completions"
comp_zsh="$PREFIX/share/zsh/site-functions"
mkdir -p "$comp_bash" "$comp_zsh" 2>/dev/null || true
cp "$SRC_DIR/share/completions/cue.bash" "$comp_bash/cue" 2>/dev/null || true
cp "$SRC_DIR/share/completions/_cue"      "$comp_zsh/_cue"  2>/dev/null || true

ver="$("$BIN" --version)"
info "installed cue $ver -> $BIN"
case ":$PATH:" in
  *":$PREFIX/bin:"*) ;;
  *) info "add to PATH:  export PATH=\"$PREFIX/bin:\$PATH\"" ;;
esac
info "engines are discovered on PATH — install cue-alexa and/or cue-google separately"
info "verify:  cue engines"
