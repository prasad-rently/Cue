# Using cue-google under the unified `cue` umbrella

`cue-google` works standalone. When the `cue` umbrella is installed it discovers
this engine on PATH via `cue-google --cue-engine-info` and routes to it:

```bash
cue --google "what time is it"     # force this engine
cue "turn on the lights"           # auto-route by config/default
cue --both "good morning"          # fan out to all engines
```

This engine never depends on `cue` being present. See `CUE_README.md`.
