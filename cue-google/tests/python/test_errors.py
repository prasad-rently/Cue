"""Tests for cue_google.errors — CUE-G-13 (gRPC error -> exit code).
Maps Google gRPC status names to the exit codes in CUE_GOOGLE_EXECUTION_PLAN.md §10.
"""
import pytest

from cue_google import errors


def test_exit_code_constants():
    assert errors.EXIT_OK == 0
    assert errors.EXIT_USAGE == 2
    assert errors.EXIT_AUTH == 10
    assert errors.EXIT_CONSENT == 11
    assert errors.EXIT_ACTIVITY == 12
    assert errors.EXIT_DEVICE == 20
    assert errors.EXIT_UPSTREAM == 30
    assert errors.EXIT_NETWORK == 40
    assert errors.EXIT_TIMEOUT == 41
    assert errors.EXIT_QUOTA == 42
    assert errors.EXIT_NOTIMPL == 99


@pytest.mark.parametrize("status,expected", [
    ("UNAUTHENTICATED", 10),
    ("PERMISSION_DENIED", 11),
    ("FAILED_PRECONDITION", 12),
    ("UNAVAILABLE", 40),
    ("DEADLINE_EXCEEDED", 41),
    ("RESOURCE_EXHAUSTED", 42),
    ("INTERNAL", 30),       # unmapped -> generic upstream
    ("SOMETHING_ELSE", 30),
])
def test_grpc_status_to_exit(status, expected):
    assert errors.grpc_status_to_exit(status) == expected


def test_cue_error_carries_exit_code():
    e = errors.AuthError("token expired")
    assert e.exit_code == errors.EXIT_AUTH
    assert "token expired" in str(e)


def test_base_error_default_and_override():
    assert errors.CueError("x").exit_code == errors.EXIT_FAIL
    assert errors.CueError("x", exit_code=42).exit_code == 42
