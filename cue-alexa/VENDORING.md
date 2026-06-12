# Vendoring policy

`cue-alexa` ships a pinned copy of its single upstream dependency,
`alexa_remote_control.sh`, under [`vendor/`](vendor/). This keeps the engine
auditable (NFR-005) and reproducible, and contains Amazon-driven upstream
breakage behind one integration seam.

## Rules

1. **Pinned, never floating.** The exact commit SHA and a SHA-256 checksum are
   recorded in [`vendor/UPSTREAM.md`](vendor/UPSTREAM.md). Installs verify the
   checksum; CI fails on drift (`tests/unit/vendor.bats`).
2. **Never edit vendored files in place.** All modifications live as
   `vendor/patches/*.patch` and are applied at build/install time. This keeps the
   upstream diff reviewable and re-pinning mechanical.
3. **Audit before re-pinning.** Bumping the pin is a deliberate act: download the
   new commit, diff it against the current pin, review for anything that touches
   auth/credentials, update `UPSTREAM.md` (SHA + checksum + date), then run the
   full test suite.
4. **Single dependency cap.** Per NFR-005 the engine stays at ≤ 1 vendored upstream.
   A future swap to a different backend (e.g. the Node `alexa-remote2` fork) is an
   architectural decision recorded in `.claude/cache/decisions.md`, not an ad-hoc add.

## All upstream coupling lives in `lib/dispatcher.sh`

The rest of the engine must not call `alexa_remote_control.sh` directly. If the
upstream changes its flags, only `lib/dispatcher.sh` (and possibly a patch) changes
— the user-facing CLI stays stable (AGENT_RULES §5).
