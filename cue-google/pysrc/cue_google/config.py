"""TOML config for cue-google (CUE-G-19, FR-040..043).

Flat-key TOML at ${XDG_CONFIG_HOME:-~/.config}/cue/google/config.toml.
Reads with the stdlib tomllib (3.11+) / tomli backport; writes flat key = "value"
lines (stdlib has no TOML writer). Secure perms: dir 0700, file 0600.
"""
from __future__ import annotations

import os
from pathlib import Path

try:  # Python 3.11+
    import tomllib
except ModuleNotFoundError:  # pragma: no cover - exercised on <3.11
    import tomli as tomllib  # type: ignore


def config_dir() -> Path:
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    return Path(base) / "cue" / "google"


def config_file() -> Path:
    return config_dir() / "config.toml"


def _load() -> dict:
    f = config_file()
    if not f.exists():
        return {}
    try:
        return tomllib.loads(f.read_text())
    except tomllib.TOMLDecodeError:
        return {}


def get(key: str, default=None):
    return _load().get(key, default)


def _toml_value(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    s = str(v).replace("\\", "\\\\").replace('"', '\\"')
    return f'"{s}"'


def set(key: str, value) -> None:  # noqa: A001 - mirror config_set CLI verb
    d = config_dir()
    d.mkdir(parents=True, exist_ok=True)
    d.chmod(0o700)
    data = _load()
    data[key] = value
    body = "".join(f"{k} = {_toml_value(v)}\n" for k, v in data.items())
    f = config_file()
    f.write_text(body)
    f.chmod(0o600)


def resolve(key: str, flag_value=None, env_var: str | None = None):
    """Precedence: flag > env var > config file."""
    if flag_value:
        return flag_value
    if env_var and os.environ.get(env_var):
        return os.environ[env_var]
    return get(key)
