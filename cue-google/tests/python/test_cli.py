"""Tests for cue_google.cli — argparse dispatch + exit-code surfacing.
gRPC/doctor calls are patched so no network/creds are needed.
"""
import json

import pytest

from cue_google import cli, errors, grpc_client, config


@pytest.fixture(autouse=True)
def _isolate(tmp_path, monkeypatch):
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path))
    yield


def test_config_set_get(capsys):
    assert cli.main(["config", "set", "project_id", "p1"]) == 0
    assert cli.main(["config", "get", "project_id"]) == 0
    assert capsys.readouterr().out.strip() == "p1"


def test_help_returns_zero(capsys):
    assert cli.main(["--help"]) == 0
    assert "cue-google" in capsys.readouterr().out


def test_text_query_prints_response(monkeypatch, capsys):
    config.set("device_model_id", "m1")
    config.set("device_id", "d1")
    monkeypatch.setattr(grpc_client, "query_with_timing",
                        lambda text, m, d, **k: ("it is 5pm", 42))
    assert cli.main(["what time is it"]) == 0
    assert capsys.readouterr().out.strip() == "it is 5pm"


def test_text_query_json(monkeypatch, capsys):
    config.set("device_model_id", "m1")
    config.set("device_id", "d1")
    monkeypatch.setattr(grpc_client, "query_with_timing",
                        lambda text, m, d, **k: ("hi", 10))
    assert cli.main(["--json", "hello"]) == 0
    out = json.loads(capsys.readouterr().out)
    assert out["response_text"] == "hi"
    assert out["query"] == "hello"


def test_text_query_without_device_is_usage_error(capsys):
    rc = cli.main(["turn on the lights"])
    assert rc == errors.EXIT_USAGE
    assert "error" in capsys.readouterr().err.lower()


def test_grpc_auth_error_surfaces_exit_10(monkeypatch, capsys):
    config.set("device_model_id", "m1")
    config.set("device_id", "d1")

    def boom(text, m, d, **k):
        raise errors.AuthError("token expired — run: cue-google login")
    monkeypatch.setattr(grpc_client, "query_with_timing", boom)
    assert cli.main(["hi"]) == errors.EXIT_AUTH
    assert "login" in capsys.readouterr().err.lower()


def test_doctor_offline_json_unconfigured_is_nonzero(capsys):
    rc = cli.main(["doctor", "--offline", "--json"])
    out = json.loads(capsys.readouterr().out)
    assert out["healthy"] is False
    assert rc != 0


def test_empty_args_shows_usage(capsys):
    assert cli.main([]) == 0
    assert "cue-google" in capsys.readouterr().out
