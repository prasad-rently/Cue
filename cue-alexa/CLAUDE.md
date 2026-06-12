# CLAUDE.md — cue-alexa

Amazon Alexa engine for Cue. Pure bash, thin auditable wrapper over the vendored
`alexa-remote-control`. **Inherits all rules from [`../AGENT_RULES.md`](../AGENT_RULES.md)
and context from [`../CLAUDE.md`](../CLAUDE.md).**

- Spec: [`../CUE_ALEXA_BRD.md`](../CUE_ALEXA_BRD.md), [`../CUE_ALEXA_EXECUTION_PLAN.md`](../CUE_ALEXA_EXECUTION_PLAN.md)
- Build steps: EP-1…EP-8 (plan §8). Progress: `.claude/state/execution-state.json` → `cue-alexa`.
- Exit codes: plan §10 (mirrored in `.claude/cache/requirements-index.json`).

Engine-specific reminders:
- **All** upstream coupling lives in `lib/dispatcher.sh`. `vendor/alexa_remote_control.sh`
  is pinned and never edited in place (patches → `vendor/patches/`).
- Modes: `text` (NLU), `speak` (TTS), `routine` (automation) → upstream `-e textcommand:/speak:/automation:`.
- Auditability cap (NFR-005): ≤2000 lines bash + ≤1 upstream dep.
