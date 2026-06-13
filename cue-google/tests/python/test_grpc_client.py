"""Tests for cue_google.grpc_client — CUE-G-10/11/12/13/20. The gRPC call is a
seam (_assist) patched in tests, so no google libraries or network are needed.
"""
import pytest

from cue_google import grpc_client, errors


class FakeRpcError(Exception):
    """Mimics grpc.RpcError: .code().name gives the status name."""
    def __init__(self, status_name):
        self._name = status_name

    def code(self):
        return type("Code", (), {"name": self._name})()


def test_build_request_passes_text_verbatim():
    req = grpc_client.build_request("café — 日本語 `id` $(whoami)", "m1", "d1")
    assert req["text_query"] == "café — 日本語 `id` $(whoami)"
    assert req["device_model_id"] == "m1"
    assert req["device_id"] == "d1"


def test_result_json_shape():
    out = grpc_client.result_json("q", "r", 123, "req-1", "m", "d")
    assert out == {
        "query": "q", "response_text": "r", "latency_ms": 123,
        "request_id": "req-1", "model_id": "m", "device_id": "d",
    }


def test_empty_query_is_usage_error():
    with pytest.raises(errors.UsageError) as ei:
        grpc_client.send_text_query("", "m", "d", creds={"token": "t"})
    assert ei.value.exit_code == errors.EXIT_USAGE


def test_success_returns_response(monkeypatch):
    monkeypatch.setattr(grpc_client, "_assist", lambda creds, req, timeout: "the time is 5pm")
    out = grpc_client.send_text_query("what time is it", "m", "d", creds={"token": "t"})
    assert out == "the time is 5pm"


@pytest.mark.parametrize("status,expected", [
    ("UNAUTHENTICATED", errors.EXIT_AUTH),
    ("PERMISSION_DENIED", errors.EXIT_CONSENT),
    ("FAILED_PRECONDITION", errors.EXIT_ACTIVITY),
    ("UNAVAILABLE", errors.EXIT_NETWORK),
    ("DEADLINE_EXCEEDED", errors.EXIT_TIMEOUT),
    ("RESOURCE_EXHAUSTED", errors.EXIT_QUOTA),
    ("INTERNAL", errors.EXIT_UPSTREAM),
])
def test_grpc_errors_map_to_exit_codes(monkeypatch, status, expected):
    def boom(creds, req, timeout):
        raise FakeRpcError(status)
    monkeypatch.setattr(grpc_client, "_assist", boom)
    with pytest.raises(errors.CueError) as ei:
        grpc_client.send_text_query("hi", "m", "d", creds={"token": "t"})
    assert ei.value.exit_code == expected


def test_html_to_text_strips_style_script_and_tags():
    html = (
        "<style>.a{color:red}</style><script>var x=1;</script>"
        "<div><b>President</b>&nbsp;Emmanuel&amp;nbsp;Macron</div>"
    )
    out = grpc_client._html_to_text(html)
    assert "color:red" not in out
    assert "var x" not in out
    assert "President" in out and "Macron" in out


def test_timeout_is_deadline_exceeded(monkeypatch):
    def slow(creds, req, timeout):
        raise FakeRpcError("DEADLINE_EXCEEDED")
    monkeypatch.setattr(grpc_client, "_assist", slow)
    with pytest.raises(errors.CueError) as ei:
        grpc_client.send_text_query("hi", "m", "d", timeout=0.01, creds={"token": "t"})
    assert ei.value.exit_code == errors.EXIT_TIMEOUT
