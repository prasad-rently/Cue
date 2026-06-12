# CLAUDE.md — cue (umbrella router)

Cross-vendor router. Discovers `cue-*` engines on PATH and routes plain-text
commands to whichever ecosystem owns the target device. **Inherits all rules from
[`../AGENT_RULES.md`](../AGENT_RULES.md) and context from [`../CLAUDE.md`](../CLAUDE.md).**

- Spec: [`../CUE_README.md`](../CUE_README.md) — user contract §3, routing §4, discovery §5.
- Build steps: phases P0…P5 (README §7). Progress: `.claude/state/execution-state.json` → `cue`.

Reminders:
- The umbrella **never** parses engine-specific flags — anything it doesn't
  explicitly handle is forwarded verbatim to the selected engine (README §3).
- Discovery = `cue-*` glob on PATH + each binary's `--cue-engine-info` JSON descriptor.
- Build this **after** at least one engine exists to route to.
- Routing precedence (README §4): explicit flag → vendor subcmd → per-device map →
  default vendor → single-engine fallback → interactive prompt.
