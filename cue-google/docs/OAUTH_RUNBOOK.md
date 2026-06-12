# OAuth runbook — "what to do when consent breaks" (NFR-006)

Symptoms: **exit 10** (UNAUTHENTICATED) or **exit 11** (PERMISSION_DENIED), or
`doctor` shows `credentials FAIL`.

1. **Re-consent:** `cue-google login` (re-runs the browser flow; idempotent).
2. **Testing-mode 7-day expiry:** if your OAuth consent screen is in *Testing*,
   refresh tokens expire after 7 days. Either re-run `login` weekly, or publish the
   consent screen to *Production* (you remain the only user).
3. **Wrong account bound:** `doctor` shows which account; re-run `login` and pick the
   right Google account.
4. **Empty responses (exit 12 / activity WARN):** enable **Web & App Activity**,
   **Device Information**, and **Voice & Audio Activity** at https://myactivity.google.com.
5. **SDK deprecation:** the Assistant SDK is deprecated for *new* projects but works
   for existing OAuth clients. The gRPC layer (`grpc_client.py`) is isolated so it can
   be swapped for the newer Home API (G11) without changing the CLI.

Tokens are stored only at `~/.config/cue/google/credentials.json` (0600) and are
never logged.
