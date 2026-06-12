"""Tests for cue_google.oauth — CUE-G-01/02/03/14. Mocks the google flow so no
network or google libraries are needed. Token-safety (FR-053) is asserted.
"""
import json
import logging
import stat

import pytest

from cue_google import oauth, errors


@pytest.fixture(autouse=True)
def _isolate(tmp_path, monkeypatch):
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path))
    yield


def test_save_then_load_roundtrip_0600():
    creds = {"token": "A", "refresh_token": "R", "client_id": "cid"}
    oauth.save_credentials(creds)
    f = oauth.creds_file()
    assert stat.S_IMODE(f.stat().st_mode) == 0o600
    assert oauth.load_credentials() == creds


def test_load_missing_returns_none():
    assert oauth.load_credentials() is None


def test_redact_masks_sensitive_keys():
    red = oauth.redact({"token": "secret", "refresh_token": "r", "client_id": "ok"})
    assert red["token"] == "***REDACTED***"
    assert red["refresh_token"] == "***REDACTED***"
    assert red["client_id"] == "ok"


def test_tokens_never_logged(caplog):
    creds = {"token": "ACCESS_SECRET_XYZ", "refresh_token": "REFRESH_SECRET_XYZ"}
    with caplog.at_level(logging.DEBUG, logger="cue_google"):
        oauth.save_credentials(creds)
    assert "ACCESS_SECRET_XYZ" not in caplog.text
    assert "REFRESH_SECRET_XYZ" not in caplog.text
    # ...but the on-disk file does persist them
    assert "ACCESS_SECRET_XYZ" in oauth.creds_file().read_text()


def test_ensure_credentials_missing_raises_auth_error():
    with pytest.raises(errors.AuthError) as ei:
        oauth.ensure_credentials()
    assert ei.value.exit_code == errors.EXIT_AUTH
    assert "login" in str(ei.value).lower()


def test_login_persists_credentials_from_flow(monkeypatch):
    # Patch the (lazy) consent-flow seam so no google libs / browser are needed.
    fake = {"token": "T", "refresh_token": "R", "client_id": "c", "scopes": oauth.SCOPES}
    monkeypatch.setattr(oauth, "_run_consent_flow", lambda secret_path: fake)
    secret = oauth.client_secret_file()
    secret.parent.mkdir(parents=True, exist_ok=True)
    secret.write_text(json.dumps({"installed": {"client_id": "c"}}))
    oauth.login()
    assert oauth.load_credentials() == fake
    assert stat.S_IMODE(oauth.creds_file().stat().st_mode) == 0o600


def test_login_without_client_secret_raises(monkeypatch):
    monkeypatch.setattr(oauth, "_run_consent_flow", lambda secret_path: {})
    with pytest.raises(errors.AuthError):
        oauth.login()
