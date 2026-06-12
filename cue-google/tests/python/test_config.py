"""Tests for cue_google.config — CUE-G-19 (config + precedence). TDD red phase.

Isolation: XDG_CONFIG_HOME is redirected to a tmp dir so tests never touch the
real ~/.config. Config lives at $XDG_CONFIG_HOME/cue/google/config.toml.
"""
import stat
import pytest

from cue_google import config


@pytest.fixture(autouse=True)
def _isolate(tmp_path, monkeypatch):
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path))
    yield


def test_get_reads_value(tmp_path):
    cfg = tmp_path / "cue" / "google"
    cfg.mkdir(parents=True)
    (cfg / "config.toml").write_text('project_id = "my-proj"\n')
    assert config.get("project_id") == "my-proj"


def test_get_missing_returns_default():
    assert config.get("nope") is None
    assert config.get("nope", "fallback") == "fallback"


def test_set_then_get_roundtrips():
    config.set("device_id", "garage-pi")
    assert config.get("device_id") == "garage-pi"


def test_set_creates_dir_0700_file_0600():
    config.set("project_id", "p")
    d = config.config_dir()
    f = config.config_file()
    assert stat.S_IMODE(d.stat().st_mode) == 0o700
    assert stat.S_IMODE(f.stat().st_mode) == 0o600


def test_set_updates_existing_key_without_duplicate():
    config.set("project_id", "a")
    config.set("project_id", "b")
    assert config.get("project_id") == "b"
    text = config.config_file().read_text()
    assert text.count("project_id") == 1


def test_values_with_quotes_survive_roundtrip():
    tricky = 'has "quotes" and \\ backslash'
    config.set("k", tricky)
    assert config.get("k") == tricky


def test_resolve_precedence_flag_over_env_over_file(monkeypatch):
    config.set("device_id", "from-file")
    monkeypatch.setenv("GOOGLE_DEVICE_ID", "from-env")
    assert config.resolve("device_id", "from-flag", "GOOGLE_DEVICE_ID") == "from-flag"
    assert config.resolve("device_id", None, "GOOGLE_DEVICE_ID") == "from-env"
    monkeypatch.delenv("GOOGLE_DEVICE_ID")
    assert config.resolve("device_id", None, "GOOGLE_DEVICE_ID") == "from-file"
