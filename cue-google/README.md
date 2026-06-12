# cue-google

Google Assistant engine for [Cue](../CLAUDE.md). Bash front-end + Python gRPC core
over the official Assistant SDK. Returns the Assistant's text response on stdout.

```bash
cue-google setup                          # guided GCP/OAuth onboarding
cue-google "what's on my calendar tomorrow"
cue-google --device-id garage-pi "open the garage"
cue-google doctor
```

Spec: [CUE_GOOGLE_BRD.md](../CUE_GOOGLE_BRD.md) · [Execution plan](../CUE_GOOGLE_EXECUTION_PLAN.md).
Status: skeleton (EP-1). Consumer Google accounts only; not for commercial distribution.
