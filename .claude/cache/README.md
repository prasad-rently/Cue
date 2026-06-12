# .claude/cache — derived context cache

Pre-digested artifacts so build-agents spend tokens *building*, not re-deriving
the same facts from the BRDs every session. Everything here is **regenerable**
from the source docs — if it ever disagrees with a BRD, the BRD wins; regenerate.

| File | What it is | Regenerate when |
|------|------------|-----------------|
| `requirements-index.json` | Every FR/NFR/Goal/exit-code ID → component + one-line summary. Lets an agent resolve "FR-012" or "exit 41" without opening the full BRD. | A BRD's requirement tables change. |
| `decisions.md` | Append-only log of resolved (and still-OPEN) open questions from each plan's §9. Stops agents re-litigating settled choices. | A decision is made or a new question appears. |
| `discovery.json` | Cached host/tooling probe (bash version, jq/python/oathtool presence, OS) so setup checks aren't re-run every session. Has a TTL — stale = re-probe. | Older than its `ttl_hours`, or the toolchain changes. |

## Not the same as Claude's prompt cache

Claude Code already caches the *conversation prompt* automatically (5-min TTL).
This directory is a **project-level working cache**: durable, committed, and
shared across sessions and agents. The two are complementary.

## Rule

Cache is an optimization, never an authority. When in doubt, re-read the source
doc named in each file's `_meta.generated_from`.
