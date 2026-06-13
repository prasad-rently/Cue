# cue-google

**Talk to Google Assistant from your terminal.** Type a command, get the
Assistant's answer on stdout — and control your Google Home / Nest devices.

`cue-google` is the Google engine of the [Cue](../README.md) project: a thin bash
front-end over a Python core that uses Google's **official** Assistant SDK (OAuth 2.0
+ gRPC). It works standalone, or under the `cue` umbrella (`cue --google "..."`).

```bash
cue-google "what time is it"              # → Local Time 4:23 pm Saturday, 13 June 2026
cue-google "turn on the living room light"
answer=$(cue-google --quiet "how far is the moon")   # scriptable
```

---

## 1. Requirements

- macOS or Linux, **bash 4+** (macOS ships 3.2 → `brew install bash`)
- **Python 3.10+** (the engine manages its own venv — you don't)
- `jq`
- A **personal Google account** with the **Google Assistant API** enabled (see §3)

---

## 2. Install

### Option A — from a release (recommended)
```bash
curl -fsSL https://github.com/prasad-rently/Cue/archive/refs/tags/v0.1.1.tar.gz | tar xz
cd Cue-0.1.1/cue-google
./install.sh
# add to PATH if it installed to ~/.local:
export PATH="$HOME/.local/bin:$PATH"     # put this in ~/.zshrc to make it permanent
```

### Option B — from source
```bash
git clone https://github.com/prasad-rently/Cue && cd Cue/cue-google
./install.sh
```

Verify (no venv/Google needed yet):
```bash
cue-google --version          # 0.1.1
cue-google --cue-engine-info  # {"name":"google",...}
```

> The internal Python venv (with the Google libraries) is built **automatically**
> on the first command that needs it — the first real call takes ~30s, then it's fast.
> `cue-google --reset-venv` rebuilds it if anything breaks.

---

## 3. One-time setup (Google Cloud + OAuth)

Run `cue-google setup` for the copy-pasteable version. Full walkthrough:
[`docs/GCP_SETUP.md`](docs/GCP_SETUP.md). In short:

1. **Google Cloud Console** → create/select a project → **enable the "Google Assistant API"**.
2. **OAuth consent screen** → External, **Testing** mode → add your own Google account as a **Test user**.
3. **Credentials → Create OAuth client ID → Desktop app** → **Download JSON**.
4. Wire it up + log in:
   ```bash
   cue-google config set project_id <your-project-id>
   cp ~/Downloads/client_secret.json ~/.config/cue/google/client_secret.json
   cue-google login         # opens a browser — pick your account, Advanced → Allow
   ```
5. Register a virtual device (required for queries):
   ```bash
   cue-google device-model register --manufacturer Self --product cli --type LIGHT --model <project>-cli-1
   cue-google device register --model <project>-cli-1 --id cli-device-1
   ```
6. **Enable Activity Controls** at https://myaccount.google.com/activitycontrols
   (turn on **Web & App Activity**) — otherwise the Assistant returns empty answers.
7. Confirm:
   ```bash
   cue-google doctor        # all green
   cue-google "what time is it"
   ```

Secrets live only under `~/.config/cue/google/` (dir `0700`, files `0600`) and are never logged.

---

## 4. How to use it (launch from terminal)

Once installed + set up, just run `cue-google` (or `cue`) from any directory.

### Ask things (info queries)
```bash
cue-google "what's the weather today"
cue-google "who painted the mona lisa"
cue-google "how do you say hello in French"
cue-google "what's 17 times 23"
```

### Control smart-home devices
Use the **exact device/room names** as they appear in the Google Home app:
```bash
cue-google "turn on the living room light"
cue-google "turn off the bedroom light"
cue-google "set the kitchen light to 30 percent"
cue-google "turn on the fan"
cue-google "set the temperature to 24 degrees"
cue-google "activate movie time"            # a Home routine/scene
```
The **real confirmation is the device reacting** — the text reply may be a short
confirmation or empty. See the hands-on guide: [`docs/MANUAL_TEST_RUN.md`](docs/MANUAL_TEST_RUN.md).

### Output modes & flags
| Flag | Effect |
|------|--------|
| `--json` | structured output: `{query, response_text, latency_ms, model_id, device_id}` |
| `--quiet` | print only the response text (ideal for scripts) |
| `--device-id <id>` | use a specific virtual device identity |
| `--device-model <id>` | override the device model |
| `--version` / `--help` | version / help |
| `--reset-venv` | delete + rebuild the internal Python venv |

Environment overrides (precedence: flag > env > config): `GOOGLE_DEVICE_ID`,
`GOOGLE_DEVICE_MODEL`, `GOOGLE_PROJECT_ID`.

### Scripting
```bash
weather=$(cue-google --quiet "weather in Chennai")
echo "$weather"

# capture structured data
cue-google --json "what time is it" | jq -r '.response_text'

# a tiny "good morning" routine
for d in "living room light" "kitchen light"; do cue-google "turn on the $d"; done
```

### Subcommands
```bash
cue-google setup                       # GCP/OAuth walkthrough
cue-google login                       # (re)authorize
cue-google doctor [--json|--offline]   # health check
cue-google config get|set <key> [val]
cue-google device-model {register,list,delete}
cue-google device {register,list,delete}
```

### Under the umbrella (optional)
If the `cue` router is installed:
```bash
cue --google "what time is it"     # force this engine
cue "what time is it"              # auto-route (set default_vendor = "google"
                                   #  in ~/.config/cue/config.toml)
```

---

## 5. Troubleshooting

| Symptom | Fix |
|--------|-----|
| `command not found: cue-google` | `~/.local/bin` isn't on PATH → `export PATH="$HOME/.local/bin:$PATH"` |
| Empty answers (exit 0, no text) | Enable **Web & App Activity** at myactivity.google.com |
| `error ... exit 10/11` (auth) | Token expired (Testing mode ~weekly) → `cue-google login` again |
| `couldn't find a device named X` | Name doesn't match Google Home exactly — check the Home app |
| `access_denied` during login | Add your account as a **Test user** on the OAuth consent screen |
| Venv/install errors | `cue-google --reset-venv` |
| Verbose answers (math/definitions) | Google sends a "featured snippet" passage; the answer is in there |

Runbook for auth/SDK issues: [`docs/OAUTH_RUNBOOK.md`](docs/OAUTH_RUNBOOK.md).

---

## 6. Notes & status

- **Status: working** against real Google accounts via the official API (v0.1.1).
- The Assistant SDK is **deprecated for new projects** but functional for enabled
  ones; the gRPC layer is isolated so it can move to the newer Home API later.
- Consumer Google accounts only. Personal automation; **not for commercial distribution**.
- Spec: [CUE_GOOGLE_BRD.md](../CUE_GOOGLE_BRD.md) · [Execution plan](../CUE_GOOGLE_EXECUTION_PLAN.md)
- Validate offline (no account): [`VALIDATION.md`](VALIDATION.md)
