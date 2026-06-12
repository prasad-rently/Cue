#!/usr/bin/env bash
# Raycast Script Command for cue-alexa.
# @raycast.schemaVersion 1
# @raycast.title Alexa command
# @raycast.mode compact
# @raycast.packageName Cue
# @raycast.icon 🗣️
# @raycast.argument1 { "type": "text", "placeholder": "say to Alexa" }
exec cue-alexa --device "Living Room" "$1"
