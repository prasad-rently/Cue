# Auth runbook — "what to do when Amazon breaks login" (NFR-007)

Amazon rotates its login flow every ~60–90 days. Symptoms: `doctor` shows
`auth: missing`, or commands fail with **exit 10** (auth) / **exit 11** (refresh).

## 1. Re-run login
```bash
cue-alexa login            # try credentials+TOTP first
```

## 2. If credential login fails (common in some regions, e.g. amazon.in)
Use cookie capture:
1. Log in to `https://alexa.amazon.<tld>` in your browser.
2. Export cookies in **Netscape format** (a "cookies.txt" browser extension).
3. Import:
   ```bash
   cue-alexa login --cookie ~/Downloads/cookies.txt
   cue-alexa doctor
   ```

## 3. If it still fails
- Confirm your region: `cue-alexa config get region` (set e.g. `amazon.in`).
- Wait if rate-limited (**exit 41**): do **not** retry aggressively — that risks an
  account lock. Back off for a few minutes.
- Check whether the vendored upstream needs a re-pin (see `vendor/UPSTREAM.md`).
  A newer commit may fix an Amazon-side change.

## Exit-code quick reference
`10` auth missing/expired · `11` refresh failed · `40` network · `41` rate-limit.
