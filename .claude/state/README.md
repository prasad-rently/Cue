# .claude/state — execution state

`execution-state.json` is the **single source of truth** for how far the phased
build has progressed. It survives across Claude Code sessions (which otherwise
start cold), so any agent — or you — can pick up exactly where the last one left off.

## Protocol (every build session)

1. **Start:** read `execution-state.json`. Find the active/next step.
2. **During:** mark the step `in_progress`
   (`.claude/scripts/state.sh active <component> <step>`).
3. **End:** set the step's real status and a one-line note
   (`.claude/scripts/state.sh set <component> <step> done "..."`).

Status values: `todo` → `in_progress` → `done`, or `blocked` when an OPEN
decision in [`../cache/decisions.md`](../cache/decisions.md) stops progress.

## Why a file and not memory

Prompt-cache and conversation context evaporate between sessions. A committed
JSON file does not. Treat it like a build manifest: it is reviewed in PRs and is
the contract the `/cue-next` slash command reads. **Never hand-edit it past a
quick fix** — go through `state.sh` so the shape stays valid.

## Steps map to the plans

- `cue-alexa` / `cue-google`: `execution_prompts` EP-1…EP-8 (each plan's §8).
- `cue`: `phases` P0…P5 (CUE_README.md §7).
