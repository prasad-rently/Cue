"""Tests for cue_google.devices — CUE-G-06/07/08/09. The Device Registration REST
call is a seam (_api) patched in tests, so no network/creds are needed.
"""
import pytest

from cue_google import devices, config, errors


@pytest.fixture(autouse=True)
def _isolate(tmp_path, monkeypatch):
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path))
    yield


@pytest.fixture
def fake_api(monkeypatch):
    calls = []
    state = {"deviceModels": [], "devices": []}

    def _api(method, path, body=None):
        calls.append((method, path, body))
        if method == "GET" and path == "/deviceModels":
            return {"deviceModels": state["deviceModels"]}
        if method == "GET" and path == "/devices":
            return {"devices": state["devices"]}
        return {}

    monkeypatch.setattr(devices, "_api", _api)
    return calls, state


def test_register_model_calls_api_and_persists_default(fake_api):
    calls, _ = fake_api
    devices.register_model("cli-assistant-1", manufacturer="Self", product_name="cli")
    assert any(m == "POST" and p == "/deviceModels" for m, p, _ in calls)
    assert config.get("device_model_id") == "cli-assistant-1"


def test_list_models(fake_api):
    _, state = fake_api
    state["deviceModels"] = [{"deviceModelId": "m1"}, {"deviceModelId": "m2"}]
    assert len(devices.list_models()) == 2


def test_register_instance_enforces_unique_id(fake_api):
    _, state = fake_api
    state["devices"] = [{"id": "cli-1"}]
    with pytest.raises(errors.DeviceError):
        devices.register_instance("m1", "cli-1")


def test_register_instance_persists_defaults(fake_api):
    devices.register_instance("m1", "cli-2", nickname="kitchen")
    assert config.get("device_model_id") == "m1"
    assert config.get("device_id") == "cli-2"


def test_list_instances(fake_api):
    _, state = fake_api
    state["devices"] = [{"id": "cli-1"}, {"id": "cli-2"}]
    assert {d["id"] for d in devices.list_instances()} == {"cli-1", "cli-2"}


def test_delete_helpers_call_api(fake_api):
    calls, _ = fake_api
    devices.delete_instance("cli-1")
    devices.delete_model("m1")
    assert ("DELETE", "/devices/cli-1", None) in calls
    assert ("DELETE", "/deviceModels/m1", None) in calls
