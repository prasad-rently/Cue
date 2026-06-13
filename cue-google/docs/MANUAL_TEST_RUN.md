# cue-google — Manual test run (control devices)

A hands-on script to verify `cue-google` works on your machine and to **control
your Google Home / Nest devices** from the terminal. Run these yourself and watch
both the terminal *and* the physical devices.

> Setup not done yet? See the [README](../README.md) §3 first (`cue-google doctor`
> should be all green before you start).

---

## Prerequisites for device control

The Assistant SDK can drive smart-home devices, but only when **all** of these hold:

1. You have smart devices (lights, plugs, switches, thermostat…) **added to the
   Google Home app** on the **same Google account** you logged in with.
2. You use the **exact device or room name** as shown in Google Home
   (e.g. *"Living Room Light"*, not *"the lamp"*).
3. Because the CLI's virtual device isn't placed in a room, prefer **explicit
   names** — `"turn on the living room light"`, not just `"turn on the lights"`.

No smart devices linked yet? Parts 1, 4, 5 still work; add devices in the Google
Home app to do Part 2.

---

## Part 1 — Confirm it's alive (info queries — always work)

```bash
cue-google "what time is it"
cue-google "what's the weather today"
cue-google "who painted the mona lisa"
cue-google "how many ounces are in a pound"
```
**Expect:** a real text answer within ~3 seconds. If these are **empty**, enable
**Web & App Activity** at https://myaccount.google.com/activitycontrols.

---

## Part 2 — Control your devices

Replace the names with **your** exact Google Home device/room names.

```bash
# Lights
cue-google "turn on the living room light"
cue-google "turn off the bedroom light"
cue-google "set the kitchen light to 30 percent"
cue-google "make the living room lights warmer"

# Plugs / switches
cue-google "turn on the fan"
cue-google "turn off the coffee maker"

# Thermostat
cue-google "set the temperature to 24 degrees"

# Scenes / routines you've created in Google Home
cue-google "activate movie time"
```

**What to watch:** the **device physically reacting** is the real success signal.
The text reply may be a short confirmation, empty, or an error like
*"Sorry, I couldn't find a device named X"* (→ name mismatch; check the Home app).

---

## Part 3 — Query device state

```bash
cue-google "is the living room light on"
cue-google "what's the temperature in the bedroom"
cue-google "are any lights on"
```

---

## Part 4 — Scripting (the point of a CLI)

```bash
# capture a response
w=$(cue-google --quiet "weather in Chennai"); echo "Weather: $w"

# structured output
cue-google --json "what time is it" | jq -r '.response_text'

# a "good morning" macro
for d in "living room light" "kitchen light" "bedroom light"; do
  cue-google "turn on the $d"
done

# a "leaving home" macro
for d in "all the lights" "the fan"; do cue-google "turn off $d"; done
```

Wire these into cron, a shell alias, Raycast, a Stream Deck button, etc.

---

## Part 5 — Under the unified `cue` umbrella (if installed)

```bash
cue --google "what time is it"     # force the Google engine
cue "turn on the living room light" # bare cue (with default_vendor = "google")
```

---

## What to report if something fails

| You see | Likely cause | Fix |
|---------|--------------|-----|
| Empty text on info queries | Activity Controls off | enable Web & App Activity |
| "couldn't find a device named …" | name ≠ Google Home name | use the exact name from the Home app |
| Nothing happens, no error | device not linked to this account, or virtual device has no room | add device in Home app; or assign a structure (ask me) |
| `exit 10` / auth error | OAuth token expired (Testing mode) | `cue-google login` |
| `exit 12` / empty everywhere | Activity Controls / `FAILED_PRECONDITION` | enable activity controls |

Exit codes: `0` ok · `10` auth · `11` consent · `12` activity-controls ·
`40` network · `41` timeout · `42` quota. Full list: README §5 / plan §10.

---

## Quick "is it all working?" one-liner

```bash
cue-google doctor && cue-google "what time is it"
```
Green doctor + a real answer = you're fully live.
