"""Device model + instance management for cue-google (CUE-G-06/07/08/09, FR-010..014).

Wraps the Google Device Registration REST API. The transport (_api) is a seam,
patched in tests and lazily importing requests/google-auth, so the management
logic (uniqueness checks, config persistence) is unit-testable offline.
"""
from __future__ import annotations

from . import config, oauth
from .errors import DeviceError, UsageError

API_BASE = "https://embeddedassistant.googleapis.com/v1alpha2"


def _api(method, path, body=None):  # pragma: no cover - needs network/creds
    """Call the Device Registration REST API. Seam: patched in tests."""
    import requests  # type: ignore

    creds = oauth.ensure_credentials()
    project_id = config.get("project_id")
    if not project_id:
        raise UsageError("project_id not set — run: cue-google setup")
    url = f"{API_BASE}/projects/{project_id}{path}"
    headers = {"Authorization": f"Bearer {creds['token']}"}
    resp = requests.request(method, url, json=body, headers=headers, timeout=15)
    if resp.status_code >= 400:
        # Surface the API's error message instead of a raw traceback.
        raise UpstreamError(f"device API {method} {path} -> {resp.status_code}: {resp.text[:300]}")
    return resp.json() if resp.content else {}


def register_model(model_id, manufacturer, product_name, device_type="LIGHT"):
    # The Device Registration API (v1alpha2) uses snake_case and wants project_id
    # in the body (validated live — camelCase / missing project_id => 400).
    body = {
        "project_id": config.get("project_id"),
        "device_model_id": model_id,
        "manifest": {
            "manufacturer": manufacturer,
            "product_name": product_name,
            "device_description": product_name,
        },
        "device_type": f"action.devices.types.{device_type}",
    }
    _api("POST", "/deviceModels", body)
    config.set("device_model_id", model_id)
    return model_id


def list_models():
    return _api("GET", "/deviceModels").get("deviceModels", [])


def delete_model(model_id):
    _api("DELETE", f"/deviceModels/{model_id}")


def list_instances():
    return _api("GET", "/devices").get("devices", [])


def register_instance(model_id, device_id, nickname=None):
    existing = {d.get("id") for d in list_instances()}
    if device_id in existing:
        raise DeviceError(f"device_id already exists in this project: {device_id}")
    body = {"id": device_id, "model_id": model_id, "nickname": nickname or device_id,
            "client_type": "SDK_SERVICE"}
    _api("POST", "/devices", body)
    config.set("device_model_id", model_id)
    config.set("device_id", device_id)
    return device_id


def delete_instance(device_id):
    _api("DELETE", f"/devices/{device_id}")
