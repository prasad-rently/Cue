# Cron / launchd recipes

Use absolute paths in cron (minimal PATH). Examples:

```cron
# 22:00 nightly — remind to start the dishwasher
0 22 * * *  /usr/local/bin/cue-alexa --mode speak --device "Kitchen" "start the dishwasher" >/dev/null 2>&1

# every 30 min 9–18 — if garage sensor file present, announce
*/30 9-18 * * *  test -f /tmp/garage_open && /usr/local/bin/cue-alexa --all "the garage is still open"

# 07:00 weekdays — trigger the Morning routine
0 7 * * 1-5  /usr/local/bin/cue-alexa --mode routine --device "Bedroom" "Morning Routine"
```

macOS launchd: wrap the same command in a LaunchAgent plist with
`<key>StartCalendarInterval</key>`.
