---
description: Execute the next pending Cue execution-prompt (EP/phase) end to end
allowed-tools: Bash, Read, Edit, Write, Glob, Grep
---

You are advancing the Cue phased build by exactly ONE step.

1. Read `.claude/state/execution-state.json` and `AGENT_RULES.md`.
2. Determine the next actionable step: run `.claude/scripts/state.sh next`
   (respect the `suggested_order` in the state file). If `$ARGUMENTS` names a
   specific `<component> <step>`, do that one instead.
3. Mark it active: `.claude/scripts/state.sh active <component> <step>` and set
   its status to `in_progress`.
4. Open that component's spec (the BRD + execution plan in the `spec` array)
   and find the matching EP/phase block. Use `.claude/cache/requirements-index.json`
   to resolve any FR/NFR/exit-code IDs instead of re-reading the full BRD.
5. Implement the step's Tasks. Honour every rule in `AGENT_RULES.md`.
6. Run the step's own **Acceptance** checks (they are listed in the EP block).
   Do not declare done until they pass.
7. On success: `.claude/scripts/state.sh set <component> <step> done "<one-line outcome>"`.
   If blocked (e.g. an OPEN decision in `.claude/cache/decisions.md`), set status
   `blocked`, record why, and stop — surface the decision to the user.

Report what you changed, the acceptance result, and the new next step.
