"""Tests for cue_google.doctor — CUE-G-15/16/17. Network/activity probes are
seams patched in tests; checks otherwise read the isolated config dir.
"""
import json

import pytest

from cue_google import doctor, oauth, config


@pytest.fixture(autouse=True)
def _isolate(tmp_path, monkeypatch):
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path))
    yield


def _status(report, name):
    return next(c["status"] for c in report["checks"] if c["name"] == name)


def test_unconfigured_offline_is_unhealthy_but_runs():
    report = doctor.run(offline=True)
    assert report["healthy"] is False
    assert _status(report, "credentials") == doctor.FAIL
    assert _status(report, "client_secret") == doctor.FAIL
    assert _status(report, "network") == doctor.SKIP
    assert _status(report, "activity_controls") == doctor.SKIP


def test_offline_skips_network(monkeypatch):
    called = {"n": False}
    monkeypatch.setattr(doctor, "_probe_network", lambda: called.__setitem__("n", True))
    doctor.run(offline=True)
    assert called["n"] is False


def test_healthy_when_configured(monkeypatch):
    oauth.save_credentials({"token": "t", "refresh_token": "r"})
    oauth.client_secret_file().write_text(json.dumps({"installed": {}}))
    config.set("device_model_id", "m1")
    config.set("device_id", "d1")
    config.set("project_id", "p1")
    report = doctor.run(offline=True)
    assert report["healthy"] is True
    assert _status(report, "credentials") == doctor.PASS
    assert _status(report, "device_model") == doctor.PASS


def test_activity_controls_empty_response_warns(monkeypatch):
    oauth.save_credentials({"token": "t"})
    oauth.client_secret_file().write_text("{}")
    config.set("device_model_id", "m1")
    config.set("device_id", "d1")
    monkeypatch.setattr(doctor, "_probe_network", lambda: True)
    monkeypatch.setattr(doctor, "_probe_activity", lambda: "")  # empty -> WARN
    report = doctor.run(offline=False)
    assert _status(report, "activity_controls") == doctor.WARN
    hint = next(c["hint"] for c in report["checks"] if c["name"] == "activity_controls")
    assert "myactivity.google.com" in hint
