# AGENT_RULES.md — rules for any agent building Cue

These are non-negotiable. They apply to every component and every execution
prompt. If a rule conflicts with a task, stop and surface it — do not silently
deviate.

## 1. Read before you write
- Read the relevant BRD + execution plan fully before touching that component.
- Resolve `FR-*` / `NFR-*` / exit-code references via
  `.claude/cache/requirements-index.json` first; only open the BRD if the cache
  is insufficient.
- Check `.claude/cache/decisions.md`. If the EP depends on an **OPEN** question,
  mark the step `blocked` in state and ask the user — do not guess.

## 2. Test-driven development (mandatory)
- **Tests come first.** For any feature, write the test case (in `TEST_PLAN.md`)
  and the executable test (`bats`/`pytest`) BEFORE the implementation.
- Follow red → green → refactor: confirm the test fails for the right reason,
  implement the minimum to pass, then clean up with tests still green.
- No implementation code lands for a feature whose tests don't exist yet.
- Every feature ID in `ROADMAP.md` maps to one or more `TC-*` IDs in `TEST_PLAN.md`.

## 3. One step at a time
- The unit of work is a single EP (engines) or phase (umbrella). Do not jump ahead.
- Each EP ends with an **Acceptance** block. It is a gate, not a suggestion: run
  the checks, paste/observe the results, and only then mark the step `done`.
- Update `.claude/state/execution-state.json` via `.claude/scripts/state.sh`
  (active → in_progress → done/blocked). Never hand-edit the JSON beyond trivia.

## 4. Stay in scope
- Build only what the current EP specifies. Spotted unrelated work? Note it in
  `decisions.md` or flag it — don't fold it in.
- Don't add dependencies beyond each plan's §2 tech-stack table without a recorded decision.

## 5. Layering / stability (the whole point of the architecture)
- The user-facing CLI (`bin/cue-*`) must stay stable even as internals change.
- **Alexa:** ALL upstream coupling lives in `lib/dispatcher.sh`. Never edit the
  vendored `vendor/alexa_remote_control.sh` in place — patches go in `vendor/patches/`.
- **Google:** the gRPC layer (`pysrc/cue_google/grpc_client.py`) is the isolated
  swap point for a future Home API migration — keep it behind a clean boundary.
- Engines must run standalone; the umbrella is discovered via PATH, never imported.

## 6. Security & privacy (hard requirements)
- Secrets live only under `~/.config/cue/<vendor>/`, dir mode 0700, secret files 0600.
- Never log or echo cookies, passwords, TOTP seeds, OAuth tokens, or refresh tokens.
- Quote/escape every byte of user-supplied command text passed to a shell or
  upstream (FR-017 Alexa / FR-023 Google). Add/keep an injection-safety test.
- No telemetry without explicit opt-in. No network calls for `--help`/`config`/offline paths.
- Never require sudo/root.

## 7. Quality bars
- All bash: `#!/usr/bin/env bash`, `set -euo pipefail`, passes `shellcheck` clean.
- Tests are part of "done": `bats` for bash, `pytest` for Python (Google CI gate: coverage > 70%).
- Use the documented exit-code constants from `lib/errors.sh` / `errors.py`, never magic numbers.
- Handle the failure modes the EP names explicitly (auth / network / device-not-found / upstream).

## 8. Commits
- Commit per the title given in the EP when one is specified (e.g.
  `chore: bootstrap repo skeleton from BRD v0.1`). Keep commits scoped to the step.
- Only commit/push when the user asks.
