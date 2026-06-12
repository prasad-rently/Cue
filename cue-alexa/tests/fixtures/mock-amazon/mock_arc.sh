#!/usr/bin/env bash
# mock_arc.sh — stand-in for alexa_remote_control.sh used as TEST DATA.
# Records each argv element (one per line) to $MOCK_ARGV_FILE, emits canned
# output for known queries, and exits with ${MOCK_EXIT:-0}. No network, no eval.
set -u
: > "${MOCK_ARGV_FILE:-/dev/null}"
for a in "$@"; do printf '%s\n' "$a" >> "${MOCK_ARGV_FILE:-/dev/null}"; done

# -a : list available devices (one accountName per line), mirrors upstream list_devices()
for a in "$@"; do
  if [ "$a" = "-a" ]; then
    printf '%s\n' "Living Room" "Bedroom Echo" "Kitchen"
    exit "${MOCK_EXIT:-0}"
  fi
done

exit "${MOCK_EXIT:-0}"
