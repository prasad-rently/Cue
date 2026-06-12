# GCP setup walkthrough

Run `cue-google setup` for the copy-pasteable version. Summary:

1. `gcloud projects create <id>` (or pick an existing project).
2. `gcloud services enable embeddedassistant.googleapis.com --project <id>`
3. Console → APIs & Services → OAuth consent screen: **External**, mode **Testing**,
   add your own account under **Test users**.
4. Console → Credentials → Create credentials → **OAuth client ID** → **Desktop app**.
   Download the JSON.
5. Wire it up:
   ```bash
   cue-google config set project_id <id>
   cp ~/Downloads/client_secret_*.json ~/.config/cue/google/client_secret.json
   cue-google login
   ```
6. Register a virtual device:
   ```bash
   cue-google device-model register --manufacturer Self --product cli --type LIGHT --model cli-1
   cue-google device register --model cli-1 --id cli-1
   cue-google doctor
   ```
