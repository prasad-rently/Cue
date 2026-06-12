"""CLI dispatch for cue-google (FR-042, FR-050..052).

Invoked by bin/cue-google via the venv bridge as `python -m cue_google.cli`.
A bare invocation with no subcommand is treated as a text query. All CueErrors
are caught and surfaced as the documented process exit code; tokens are never
printed.
"""
from __future__ import annotations

import json
import sys

from . import config, devices, doctor, grpc_client, oauth
from .errors import CueError, UsageError, EXIT_OK

USAGE = """\
cue-google — send text commands to Google Assistant / Home / Nest.

USAGE:
  cue-google [--json|--quiet] [--device-id <id>] [--device-model <id>] "<text>"
  cue-google <subcommand> [args]

SUBCOMMANDS:
  setup                          guided GCP / OAuth onboarding
  login                          run / refresh OAuth consent
  doctor [--json|--offline]      health checks
  device-model {register,list,delete}
  device {register,list,delete}
  config get <key> | config set <key> <value>
"""

_SUBCOMMANDS = {"setup", "login", "doctor", "device-model", "device", "config"}


def _cmd_query(argv):
    json_out = quiet = False
    device_id = model = None
    words = []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--json":
            json_out = True
        elif a == "--quiet":
            quiet = True
        elif a == "--device-id":
            i += 1; device_id = argv[i]
        elif a == "--device-model":
            i += 1; model = argv[i]
        elif a == "--":
            words.extend(argv[i + 1:]); break
        else:
            words.append(a)
        i += 1

    text = " ".join(words)
    if not text:
        raise UsageError("no query text given (try: cue-google --help)")

    model = config.resolve("device_model_id", model, "GOOGLE_DEVICE_MODEL")
    device_id = config.resolve("device_id", device_id, "GOOGLE_DEVICE_ID")
    if not model or not device_id:
        raise UsageError(
            "no device configured — run: cue-google setup, then device-model/device register"
        )

    response, latency_ms = grpc_client.query_with_timing(text, model, device_id)
    if json_out:
        print(json.dumps(grpc_client.result_json(text, response, latency_ms, "", model, device_id)))
    elif response or not quiet:
        print(response)
    return EXIT_OK


def _cmd_doctor(argv):
    json_out = "--json" in argv
    offline = "--offline" in argv
    report = doctor.run(offline=offline)
    if json_out:
        print(json.dumps(report))
    else:
        for c in report["checks"]:
            line = f"[{c['status']}] {c['name']}"
            if c["hint"]:
                line += f"  — {c['hint']}"
            print(line)
    return EXIT_OK if report["healthy"] else 1


def _cmd_config(argv):
    if len(argv) >= 2 and argv[0] == "get":
        val = config.get(argv[1])
        if val is None:
            raise UsageError(f"key not set: {argv[1]}")
        print(val)
        return EXIT_OK
    if len(argv) >= 3 and argv[0] == "set":
        config.set(argv[1], argv[2])
        return EXIT_OK
    raise UsageError("config get <key> | config set <key> <value>")


def _cmd_login(_argv):
    oauth.login()
    print("cue-google: OAuth consent complete; credentials saved.")
    return EXIT_OK


def _cmd_setup(_argv):
    print(
        "cue-google setup — one-time Google Cloud + OAuth onboarding:\n"
        "  1. Create/select a GCP project:  gcloud projects create <id>\n"
        "  2. Enable the Assistant API:      gcloud services enable embeddedassistant.googleapis.com\n"
        "  3. Configure the OAuth consent screen (External/Testing; add yourself as a test user).\n"
        "  4. Create a Desktop OAuth client, download the JSON, then:\n"
        "       cue-google config set project_id <id>\n"
        "       cp <downloaded>.json ~/.config/cue/google/client_secret.json\n"
        "       cue-google login\n"
        "  5. Register a device model + instance:  cue-google device-model register ...\n"
    )
    return EXIT_OK


def _cmd_device_model(argv):
    action = argv[0] if argv else ""
    rest = argv[1:]
    if action == "list":
        print(json.dumps(devices.list_models()))
    elif action == "register":
        opts = _kv(rest)
        mid = devices.register_model(
            opts.get("--model", "cue-assistant-1"),
            manufacturer=opts.get("--manufacturer", "Self"),
            product_name=opts.get("--product", "cli"),
            device_type=opts.get("--type", "LIGHT"),
        )
        print(f"registered device model: {mid}")
    elif action == "delete":
        devices.delete_model(rest[0])
    else:
        raise UsageError("device-model {register,list,delete}")
    return EXIT_OK


def _cmd_device(argv):
    action = argv[0] if argv else ""
    rest = argv[1:]
    if action == "list":
        print(json.dumps(devices.list_instances()))
    elif action == "register":
        opts = _kv(rest)
        did = devices.register_instance(
            opts.get("--model") or config.get("device_model_id"),
            opts.get("--id", "cue-1"),
            nickname=opts.get("--nickname"),
        )
        print(f"registered device: {did}")
    elif action == "delete":
        devices.delete_instance(rest[0])
    else:
        raise UsageError("device {register,list,delete}")
    return EXIT_OK


def _kv(argv):
    out = {}
    i = 0
    while i < len(argv) - 1:
        if argv[i].startswith("--"):
            out[argv[i]] = argv[i + 1]
            i += 2
        else:
            i += 1
    return out


_DISPATCH = {
    "doctor": _cmd_doctor,
    "config": _cmd_config,
    "login": _cmd_login,
    "setup": _cmd_setup,
    "device-model": _cmd_device_model,
    "device": _cmd_device,
}


def main(argv=None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    try:
        if not argv or argv[0] in ("--help", "-h"):
            print(USAGE)
            return EXIT_OK
        cmd = argv[0]
        if cmd in _DISPATCH:
            return _DISPATCH[cmd](argv[1:])
        return _cmd_query(argv)
    except CueError as exc:
        print(f"cue-google: error: {exc}", file=sys.stderr)
        return exc.exit_code


if __name__ == "__main__":
    raise SystemExit(main())
