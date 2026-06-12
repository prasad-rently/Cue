# Vendored upstream — `alexa_remote_control.sh`

| Field | Value |
|-------|-------|
| Project | [thorsten-gehrig/alexa-remote-control](https://github.com/thorsten-gehrig/alexa-remote-control) |
| File | `alexa_remote_control.sh` |
| Pinned commit | `b7077400cf1837ba6455c5e9265bf03a8fdd8d9f` |
| Commit date | 2025-11-08T11:31:22Z |
| Vendored on | 2026-06-12 |
| Source URL | https://raw.githubusercontent.com/thorsten-gehrig/alexa-remote-control/b7077400cf1837ba6455c5e9265bf03a8fdd8d9f/alexa_remote_control.sh |
| License | Apache-2.0 |
| SHA-256 | `b96f32d69370db5274b6c1ddfc3ad61eae4db5220c2f5018826491800ad080eb` |

## Why this is vendored

`cue-alexa` is a thin, auditable wrapper over this community-maintained script,
which is the only working path for arbitrary text → Echo execution on a personal
account (BRD §3). Per BRD §10 (Risks), the upstream breaks on a roughly 60–90 day
cadence as Amazon rotates its auth flow and endpoints. Pinning a known-good commit
and vendoring it:

- contains upstream instability behind a single integration layer (`lib/dispatcher.sh`);
- gives reproducible installs (the SHA-256 above is verified by `tests/unit/vendor.bats`);
- lets us audit exactly what runs against the user's Amazon account (NFR-005).

## Policy (see ../VENDORING.md)

- **Never edit this file in place.** Local changes go in `patches/*.patch`, applied
  at build/install time.
- Re-pin deliberately: bump the commit SHA, re-download, update the SHA-256 here,
  and re-run the test suite. Audit the diff before adopting a new pin.

## Verify it hasn't drifted

```sh
shasum -a 256 vendor/alexa_remote_control.sh
# must equal the SHA-256 recorded above
```
