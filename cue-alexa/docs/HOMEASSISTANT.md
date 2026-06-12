# Home Assistant integration

Use `shell_command:` to call cue-alexa from automations. Use the **full path** to
the installed launcher (HA runs as its own user).

```yaml
# configuration.yaml
shell_command:
  alexa_say: '/usr/local/bin/cue-alexa --mode speak --device "{{ device }}" "{{ message }}"'
  alexa_routine: '/usr/local/bin/cue-alexa --mode routine --device "Living Room" "{{ name }}"'
  alexa_text: '/usr/local/bin/cue-alexa --device "{{ device }}" "{{ command }}"'
```

```yaml
# automation: announce when the garage door opens
automation:
  - alias: Announce garage open
    trigger:
      - platform: state
        entity_id: binary_sensor.garage_door
        to: "on"
    action:
      - service: shell_command.alexa_say
        data:
          device: "Garage"
          message: "the garage door is open"
```

Cross-vendor fan-out (if the unified `cue` umbrella is installed):
```yaml
shell_command:
  cue_both: '/usr/local/bin/cue --both "{{ message }}"'
```
Exit codes propagate, so HA logs failures. Test a command by hand first
(see [COMMANDS.md](COMMANDS.md)).
