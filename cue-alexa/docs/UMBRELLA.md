# Using cue-alexa under the unified `cue` umbrella

`cue-alexa` works **standalone** — the umbrella is optional. When the separate
`cue` router is installed, it discovers this engine on `PATH` and routes to it.

- Discovery: `cue` finds any `cue-*` binary and calls `--cue-engine-info`:
  ```bash
  cue-alexa --cue-engine-info
  # {"name":"alexa","version":"0.1.0","description":"...","supports":[...]}
  ```
- Routing examples once both are installed:
  ```bash
  cue --alexa "turn on the lights"     # force this engine
  cue "turn on the lights"             # auto-route by config/default
  cue --both "good morning"            # fan out to all engines
  cue alexa devices                    # subcommand passthrough -> cue-alexa devices
  ```

This engine never depends on `cue` being present. See `CUE_README.md` for the
umbrella spec.
