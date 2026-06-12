# Decisions & resolved open questions

Append-only log so build-agents don't re-litigate settled choices. Each plan's
§9 ("Open questions") is mirrored here; resolve them as they're decided and cite
the date + who decided. **Unresolved questions still block the EP that needs them.**

Format: `- [STATUS] (YYYY-MM-DD) <decision> — rationale`
STATUS ∈ OPEN | DECIDED | DEFERRED.

## cue-alexa (from CUE_ALEXA_EXECUTION_PLAN.md §9)

- [OPEN] Region default — author primarily uses `.in`. Auto-detect via IP geolocation, or always prompt?
- [OPEN] Should the dispatcher fully abstract the upstream so swapping to `alexa-remote2` (Node) is one line?
- [OPEN] Homebrew formula: bundle `oath-toolkit` + `jq` as deps, or document as prerequisites?
- [OPEN] Telemetry — offer opt-in at all? (Lean: no.)
- [OPEN] Account `--profile` system — v1 or Phase 4?

## cue-google (from CUE_GOOGLE_EXECUTION_PLAN.md §9)

- [OPEN] Python floor — 3.10 (broad compat, needs `tomli`) or 3.11 (stdlib `tomllib`)?
- [OPEN] `cue-google setup` — shell out to `gcloud`, or print instructions to paste?
- [OPEN] Per-room device-id — first-class `--room` flag or docs recipe only?
- [OPEN] SDK shutdown — keep gRPC behind an interface from day 1, or refactor later?
- [OPEN] `--conversation-state-file` — v1 or Phase 4?

## cue umbrella (from CUE_README.md)

- [DECIDED] (2026-06-08) Name is **Cue** — stagecraft metaphor, short, verb-readable; `cuelang` overload is a different domain. (README §9)
- [DECIDED] (per spec) Umbrella forwards anything it doesn't explicitly handle verbatim to the engine; it never parses engine-specific flags. (README §3)

## Cross-cutting (set by this scaffolding)

- [DECIDED] (2026-06-12) Monorepo layout: the three components live as sibling subdirs (`cue/`, `cue-alexa/`, `cue-google/`) of this planning repo. The plans describe them as three *independent* repos that ship separately — split them out with `git subtree`/`filter-repo` if/when publishing. Engines MUST keep working standalone regardless of layout.
- [DECIDED] (2026-06-12) `CLAUDE.md` + `AGENT_RULES.md` are authored at the repo root and referenced (not duplicated) by each component's own `CLAUDE.md`.
