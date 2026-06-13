# Connecting IoT devices to Google Assistant (so cue-google can control them)

cue-google sends text commands to **your Google Assistant**, which acts on the
smart devices in **your Google Home graph**. So before cue-google can control a
light or plug, that device must be linked in **Google Home** first. cue-google
does not (and cannot) pair devices — that's Google Home's job; cue-google is the
command layer on top.

---

## First, the distinction that confuses everyone

There are **two** unrelated "devices":

| | What it is | Where it lives | Managed via |
|---|---|---|---|
| **Virtual CLI device** (`cli-device-1`) | The identity cue-google speaks *as* (the "caller") | The Assistant **SDK device registry** | `cue-google device …` |
| **IoT smart devices** (lights, plugs, fans…) | The things you actually control | Your **Google Home graph** | The **Google Home app** |

So `cue-google device list` shows only `cli-device-1` — **not** your bulbs. Your
bulbs are in Google Home. There is **no programmatic "list my IoT devices"** via
the Assistant SDK; the Google Home app is the source of truth.

---

## How to connect an IoT device (one-time, in the Google Home app)

1. Install the **Google Home** app (iOS/Android) and sign in with the **same Google
   account** you used for `cue-google login`.
2. Tap **➕ (top-left) → Set up device**.
3. Choose the path for your gadget:
   - **"New device"** — Google/Nest, **Matter**, or Thread devices you own; pairs over Wi-Fi.
   - **"Works with Google Home"** — third-party brands; search the brand and sign
     into *their* app to link it. (This is how most smart bulbs/plugs connect.)
4. Give each device a **clear name** and assign a **room**.
   That exact name is what you type:
   ```bash
   cue-google "turn on the <exact device name>"
   ```

> Tip: short, distinct names work best — "Desk Lamp", "Bedroom Light", "Living Room
> Plug". Avoid names the Assistant might mishear or that collide with rooms.

---

## Don't own a smart device yet? (India-friendly starter options)

Cheapest entry is a **smart plug** (~₹500–900), then smart bulbs. Brands that work
with Google Home in India:

- **Smart plugs:** Wipro, Syska, TP-Link Tapo, Mi/Xiaomi, boAt
- **Smart bulbs:** Wipro, Syska, Philips Hue, Mi, Halonix

Note: an **Echo / Fire TV** is Amazon Alexa, not Google — it won't show up here.

---

## See your linked devices

- **Google Home app** home screen — every device + room (authoritative).
- **Web:** https://home.google.com
- Per-device queries work once linked (`cue-google "is the bedroom light on"`), but
  there's no reliable "dump all devices" through the SDK.

---

## Control it from the terminal

```bash
cue-google "turn on the desk lamp"
cue-google "set the bedroom light to 40 percent"
cue-google "turn off the living room plug"
cue-google "is the desk lamp on"
```
The **device physically reacting** is the success signal — the text reply may be a
short confirmation or empty.

---

## Troubleshooting

| You see / hear | Cause | Fix |
|----------------|-------|-----|
| "Sorry, I couldn't find a device named X" | Name ≠ Google Home name | use the exact name from the Home app |
| Nothing happens, no error | Device not linked to *this* Google account | re-check it's added under the same account used for `cue-google login` |
| Works in the Home app but not here | Different Google account | `cue-google login` with the account that owns the devices |
| Room-relative command ignored ("turn on the lights") | The CLI's virtual device has no room | use explicit device/room names instead |

See also: [MANUAL_TEST_RUN.md](MANUAL_TEST_RUN.md) · [README](../README.md).
