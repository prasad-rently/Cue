"""Health checks for cue-google (CUE-G-15/16/17, FR-030).

Runs an ordered set of checks, each producing PASS/WARN/FAIL/SKIP plus a
remediation hint. Network and activity-control probes are seams (_probe_network,
_probe_activity) so the orchestration is testable offline.
"""
from __future__ import annotations

from . import config, oauth

PASS, WARN, FAIL, SKIP = "PASS", "WARN", "FAIL", "SKIP"


def _check(name, status, hint=""):
    return {"name": name, "status": status, "hint": hint}


def check_config():
    f = config.config_file()
    if not f.exists():
        return _check("config", WARN, "no config yet — run: cue-google setup")
    try:
        config.get("project_id")  # parse smoke test
        return _check("config", PASS)
    except Exception as exc:  # noqa: BLE001
        return _check("config", FAIL, f"unparseable config: {exc}")


def check_client_secret():
    ok = oauth.client_secret_file().exists()
    return _check("client_secret", PASS if ok else FAIL,
                  "" if ok else "missing — run: cue-google setup")


def check_credentials():
    if oauth.load_credentials() is None:
        return _check("credentials", FAIL, "run: cue-google login")
    return _check("credentials", PASS)


def check_device_model():
    m = config.get("device_model_id")
    return _check("device_model", PASS if m else WARN,
                  "" if m else "register: cue-google device-model register")


def check_device_id():
    d = config.get("device_id")
    return _check("device_id", PASS if d else WARN,
                  "" if d else "register: cue-google device register")


def _probe_network():  # pragma: no cover - real socket
    import socket

    socket.create_connection(("embeddedassistant.googleapis.com", 443), timeout=5).close()
    return True


def check_network():
    try:
        _probe_network()
        return _check("network", PASS)
    except Exception as exc:  # noqa: BLE001
        return _check("network", FAIL, f"unreachable: {exc}")


def _probe_activity():  # pragma: no cover - needs gRPC/creds
    from . import grpc_client

    return grpc_client.send_text_query(
        "say test", config.get("device_model_id"), config.get("device_id")
    )


def check_activity_controls():
    try:
        resp = _probe_activity()
    except Exception as exc:  # noqa: BLE001
        return _check("activity_controls", WARN, f"could not probe: {exc}")
    if not resp:
        return _check("activity_controls", WARN,
                      "empty response — enable Web & App Activity at myactivity.google.com")
    return _check("activity_controls", PASS)


def run(offline=False):
    checks = [
        check_config(),
        check_client_secret(),
        check_credentials(),
        check_device_model(),
        check_device_id(),
    ]
    if offline:
        checks.append(_check("network", SKIP, "--offline"))
        checks.append(_check("activity_controls", SKIP, "--offline"))
    else:
        checks.append(check_network())
        checks.append(check_activity_controls())
    healthy = all(c["status"] != FAIL for c in checks)
    return {"healthy": healthy, "offline": offline, "checks": checks}
