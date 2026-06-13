"""OAuth 2.0 for cue-google (CUE-G-01/02/03/14, FR-001..006, FR-053).

Stores credentials at ~/.config/cue/google/credentials.json (mode 0600). Tokens
are NEVER logged — any credential dict is passed through redact() before logging.
The actual google_auth_oauthlib import is lazy (inside _run_consent_flow) so this
module is importable and unit-testable without google libraries installed.
"""
from __future__ import annotations

import json
import logging
import os
from pathlib import Path

from . import config
from .errors import AuthError

logger = logging.getLogger("cue_google")

SCOPES = [
    "https://www.googleapis.com/auth/assistant-sdk-prototype",
    "https://www.googleapis.com/auth/gcm",
]

_SENSITIVE_KEYS = frozenset(
    {"token", "access_token", "refresh_token", "id_token", "client_secret"}
)


def creds_file() -> Path:
    return config.config_dir() / "credentials.json"


def client_secret_file() -> Path:
    return config.config_dir() / "client_secret.json"


def redact(obj):
    """Recursively mask sensitive values so credential dicts are safe to log."""
    if isinstance(obj, dict):
        return {
            k: ("***REDACTED***" if k in _SENSITIVE_KEYS else redact(v))
            for k, v in obj.items()
        }
    if isinstance(obj, list):
        return [redact(v) for v in obj]
    return obj


def save_credentials(creds: dict) -> None:
    d = config.config_dir()
    d.mkdir(parents=True, exist_ok=True)
    d.chmod(0o700)
    f = creds_file()
    f.write_text(json.dumps(creds))
    f.chmod(0o600)
    logger.debug("saved credentials: %s", redact(creds))


def load_credentials() -> dict | None:
    f = creds_file()
    if not f.exists():
        return None
    try:
        return json.loads(f.read_text())
    except json.JSONDecodeError:
        return None


def ensure_credentials() -> dict:
    """Return usable credentials, refreshing if needed; else raise AuthError."""
    creds = load_credentials()
    if creds is None:
        raise AuthError("no credentials found — run: cue-google login")
    return _refresh_if_needed(creds)


TOKEN_URI = "https://oauth2.googleapis.com/token"


def _refresh_if_needed(creds: dict) -> dict:
    """Refresh the access token using the refresh token, then persist it.

    Access tokens expire ~hourly, so we refresh proactively (the stored creds have
    no expiry to check). Requires google libs; if absent (e.g. unit tests), returns
    creds unchanged. All fields needed for a future refresh are preserved.
    """
    if not creds.get("refresh_token"):
        return creds
    try:
        from google.oauth2.credentials import Credentials  # type: ignore
        from google.auth.transport.requests import Request  # type: ignore
    except ModuleNotFoundError:  # pragma: no cover - tests have no google libs
        return creds

    fields = {k: v for k, v in creds.items() if not k.startswith("_")}
    fields.setdefault("token_uri", TOKEN_URI)
    try:
        c = Credentials(**fields)  # type: ignore[arg-type]
        c.refresh(Request())
    except Exception as exc:  # noqa: BLE001
        raise AuthError("token refresh failed — run: cue-google login") from exc

    updated = dict(creds)
    updated["token"] = c.token
    if c.refresh_token:
        updated["refresh_token"] = c.refresh_token
    updated["token_uri"] = TOKEN_URI
    save_credentials(updated)
    return updated


def _run_consent_flow(secret_path: str) -> dict:  # pragma: no cover - needs google libs
    """Run the installed-app OAuth flow. Seam: patched in tests. Lazy import."""
    from google_auth_oauthlib.flow import InstalledAppFlow  # type: ignore

    flow = InstalledAppFlow.from_client_secrets_file(secret_path, scopes=SCOPES)
    creds = flow.run_local_server(port=0)
    return {
        "token": creds.token,
        "refresh_token": creds.refresh_token,
        "client_id": creds.client_id,
        "client_secret": creds.client_secret,
        "scopes": list(creds.scopes or SCOPES),
    }


def login() -> dict:
    """Run the OAuth consent flow and persist credentials (idempotent, FR-004)."""
    secret = client_secret_file()
    if not secret.exists():
        raise AuthError(
            "client_secret.json not found — run: cue-google setup, then provide the "
            "downloaded OAuth client JSON"
        )
    creds = _run_consent_flow(os.fspath(secret))
    if not creds:
        raise AuthError("consent flow returned no credentials")
    save_credentials(creds)
    return creds
