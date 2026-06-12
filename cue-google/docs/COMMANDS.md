# cue-google — Command reference

```bash
# one-time onboarding
cue-google setup                 # prints GCP/OAuth steps
cue-google config set project_id <gcp-project>
cp <oauth-client>.json ~/.config/cue/google/client_secret.json
cue-google login                 # browser consent; saves credentials.json (0600)
cue-google device-model register --manufacturer Self --product cli --type LIGHT --model cli-1
cue-google device register --model cli-1 --id cli-1

# send commands
cue-google "what's on my calendar tomorrow"      # prints Assistant response
cue-google --device-id garage-pi "open the garage"
result=$(cue-google --quiet "what time is it")    # capture for scripting
cue-google --json "weather today"                 # {"query":...,"response_text":...,"latency_ms":...}

# discovery / health
cue-google doctor                # PASS/WARN/FAIL checks
cue-google doctor --json
cue-google doctor --offline      # skip network/activity probes
cue-google device-model list
cue-google device list

# config / maintenance
cue-google config get device_id
cue-google --reset-venv          # rebuild the internal Python venv
```

Precedence for device-id/device-model: **flag > env (`GOOGLE_DEVICE_ID`, `GOOGLE_DEVICE_MODEL`, `GOOGLE_PROJECT_ID`) > config**.

## Exit codes (CUE_GOOGLE_EXECUTION_PLAN.md §10)
`0` ok · `2` usage · `10` auth (UNAUTHENTICATED) · `11` consent (PERMISSION_DENIED)
· `12` activity controls (FAILED_PRECONDITION) · `20` device · `30` other gRPC
· `40` network (UNAVAILABLE) · `41` timeout (DEADLINE_EXCEEDED) · `42` quota (RESOURCE_EXHAUSTED).
