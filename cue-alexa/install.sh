#!/usr/bin/env bash
# install.sh — install cue-alexa (CUE-A-24 / FR-051). No sudo required.
#
# From a checked-out repo:   ./install.sh
# Custom prefix:             PREFIX="$HOME/.local" ./install.sh
#
# Installs the engine tree to <prefix>/libexec/cue-alexa and a launcher at
# <prefix>/bin/cue-alexa. Picks $HOME/.local automatically if <prefix> isn't writable.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

err()  { printf 'install: error: %s\n' "$*" >&2; exit 1; }
info() { printf 'install: %s\n' "$*"; }

# --- preflight: dependencies ---
if [[ -z "${BASH_VERSINFO:-}" || "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  err "bash 4+ required (found ${BASH_VERSION:-unknown}). macOS: brew install bash"
fi
command -v jq >/dev/null 2>&1 || err "jq is required (brew install jq / apt-get install jq)"
command -v oathtool >/dev/null 2>&1 || info "note: oathtool not found — needed only for credential+TOTP login"

# --- pick a writable prefix (no sudo) ---
PREFIX="${PREFIX:-/usr/local}"
if ! mkdir -p "$PREFIX/bin" 2>/dev/null || [[ ! -w "$PREFIX/bin" ]]; then
  PREFIX="$HOME/.local"
  info "falling back to PREFIX=$PREFIX (no write access to /usr/local)"
  mkdir -p "$PREFIX/bin"
fi

LIBEXEC="$PREFIX/libexec/cue-alexa"
BIN="$PREFIX/bin/cue-alexa"

# --- install the engine tree ---
info "installing to $LIBEXEC"
rm -rf "$LIBEXEC"
mkdir -p "$LIBEXEC"
cp -R "$SRC_DIR/bin" "$SRC_DIR/lib" "$SRC_DIR/vendor" "$SRC_DIR/VERSION" "$LIBEXEC/"
chmod +x "$LIBEXEC/bin/cue-alexa" "$LIBEXEC/vendor/alexa_remote_control.sh"

# verify the vendored upstream matches its recorded checksum (drift guard)
recorded="$(grep -oE '[0-9a-f]{64}' "$SRC_DIR/vendor/UPSTREAM.md" | head -1 || true)"
if [[ -n "$recorded" ]]; then
  actual="$(shasum -a 256 "$LIBEXEC/vendor/alexa_remote_control.sh" | awk '{print $1}')"
  [[ "$actual" == "$recorded" ]] || err "vendored upstream checksum mismatch (expected $recorded)"
fi

# --- launcher on PATH ---
cat > "$BIN" <<EOF
#!/usr/bin/env bash
exec "$LIBEXEC/bin/cue-alexa" "\$@"
EOF
chmod +x "$BIN"

# --- confirm ---
ver="$("$BIN" --version)"
info "installed cue-alexa $ver -> $BIN"
case ":$PATH:" in
  *":$PREFIX/bin:"*) ;;
  *) info "add to PATH:  export PATH=\"$PREFIX/bin:\$PATH\"" ;;
esac
info "next: cue-alexa login   then   cue-alexa doctor"
