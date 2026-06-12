# CLAUDE.md — cue-google

Google Assistant engine for Cue. Bash front-end + Python gRPC core over the
official (deprecated-for-new-projects) Assistant SDK. **Inherits all rules from
[`../AGENT_RULES.md`](../AGENT_RULES.md) and context from [`../CLAUDE.md`](../CLAUDE.md).**

- Spec: [`../CUE_GOOGLE_BRD.md`](../CUE_GOOGLE_BRD.md), [`../CUE_GOOGLE_EXECUTION_PLAN.md`](../CUE_GOOGLE_EXECUTION_PLAN.md)
- Build steps: EP-1…EP-8 (plan §8). Progress: `.claude/state/execution-state.json` → `cue-google`.
- Exit codes: plan §10 (mirrored in `.claude/cache/requirements-index.json`).

Engine-specific reminders:
- Python lives in an **internal venv** at `~/.config/cue/google/.venv`, managed by
  `lib/python_bridge.sh` (FR-062). Never touch system Python.
- `bin/cue-google` handles `--help`/`--version` without Python; everything else
  forwards via the bridge.
- `pysrc/cue_google/grpc_client.py` is the isolated swap point for a future Home
  API migration (G11) — keep the boundary clean.
- gRPC error → exit-code mapping is mandated (plan §10): UNAUTHENTICATED→10,
  PERMISSION_DENIED→11, FAILED_PRECONDITION→12, UNAVAILABLE→40, DEADLINE_EXCEEDED→41,
  RESOURCE_EXHAUSTED→42.
