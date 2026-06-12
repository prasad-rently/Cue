# cue-alexa

Amazon Alexa engine for [Cue](../CLAUDE.md). Pure-bash wrapper over the vendored
`alexa-remote-control`, with a stable CLI that survives upstream churn.

```bash
cue-alexa "turn on the kitchen lights"
cue-alexa --device "Bedroom" "set a timer for 10 minutes"
cue-alexa --mode speak "dinner is ready"
cue-alexa doctor
```

Spec: [CUE_ALEXA_BRD.md](../CUE_ALEXA_BRD.md) · [Execution plan](../CUE_ALEXA_EXECUTION_PLAN.md).
Status: skeleton (EP-1). Not for commercial distribution (Amazon TOS).
