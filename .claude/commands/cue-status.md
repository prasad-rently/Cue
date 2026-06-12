---
description: Show Cue phased-build progress from execution-state.json
allowed-tools: Bash(.claude/scripts/state.sh:*), Bash(jq:*), Read
---

Run `.claude/scripts/state.sh status $ARGUMENTS` and present the result as a
short progress summary. If an argument is given, scope to that component
(`cue`, `cue-alexa`, or `cue-google`). Then state which step is next per
`.claude/scripts/state.sh next`. Do not start building unless asked.
