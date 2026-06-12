"""Exit codes + exception taxonomy for cue-google (CUE-G-13, plan §10).

Maps Google gRPC status names to documented process exit codes, and provides a
small exception hierarchy whose instances carry the right exit code.
"""
from __future__ import annotations

EXIT_OK = 0
EXIT_FAIL = 1
EXIT_USAGE = 2
EXIT_AUTH = 10          # OAuth missing/expired/refresh-failed (UNAUTHENTICATED)
EXIT_CONSENT = 11       # consent revoked (PERMISSION_DENIED)
EXIT_ACTIVITY = 12      # activity controls off (FAILED_PRECONDITION)
EXIT_DEVICE = 20        # device model/instance not found
EXIT_UPSTREAM = 30      # other upstream gRPC error
EXIT_NETWORK = 40       # network UNAVAILABLE
EXIT_TIMEOUT = 41       # DEADLINE_EXCEEDED
EXIT_QUOTA = 42         # RESOURCE_EXHAUSTED
EXIT_NOTIMPL = 99       # not yet implemented (dev only)

# gRPC status name -> exit code. Unmapped statuses fall back to EXIT_UPSTREAM.
_GRPC_STATUS_EXIT = {
    "UNAUTHENTICATED": EXIT_AUTH,
    "PERMISSION_DENIED": EXIT_CONSENT,
    "FAILED_PRECONDITION": EXIT_ACTIVITY,
    "UNAVAILABLE": EXIT_NETWORK,
    "DEADLINE_EXCEEDED": EXIT_TIMEOUT,
    "RESOURCE_EXHAUSTED": EXIT_QUOTA,
}


def grpc_status_to_exit(status_name: str) -> int:
    return _GRPC_STATUS_EXIT.get(status_name, EXIT_UPSTREAM)


class CueError(Exception):
    """Base error. Carries an exit_code the CLI surfaces (never logs secrets)."""

    exit_code = EXIT_FAIL

    def __init__(self, message: str, exit_code: int | None = None):
        super().__init__(message)
        if exit_code is not None:
            self.exit_code = exit_code


class UsageError(CueError):
    exit_code = EXIT_USAGE


class AuthError(CueError):
    exit_code = EXIT_AUTH


class ConsentError(CueError):
    exit_code = EXIT_CONSENT


class ActivityControlsError(CueError):
    exit_code = EXIT_ACTIVITY


class DeviceError(CueError):
    exit_code = EXIT_DEVICE


class UpstreamError(CueError):
    exit_code = EXIT_UPSTREAM


class NetworkError(CueError):
    exit_code = EXIT_NETWORK


class TimeoutError(CueError):  # noqa: A001 - intentional domain name
    exit_code = EXIT_TIMEOUT


class QuotaError(CueError):
    exit_code = EXIT_QUOTA
