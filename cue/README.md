# cue

Umbrella router for the [Cue](../CLAUDE.md) project — discovers `cue-*` voice-assistant
engines on PATH and routes plain-text commands to the right one.

```bash
cue "turn on the lights"          # auto-routed
cue --alexa "set a timer"         # explicit vendor
cue --both "good morning"         # fan out to all engines
cue engines                       # list discovered engines
```

Spec: [CUE_README.md](../CUE_README.md). Status: skeleton (phase P0). Build after an engine exists.
