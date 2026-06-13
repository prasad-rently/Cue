"""gRPC text-query client for cue-google (CUE-G-10/11/12/13/20, FR-020..025).

This is the isolated swap point for a future migration to the newer Home API
(G11). The actual gRPC streaming lives in the _assist() seam — patched in tests —
and imports google libraries lazily, so the request-building, response-shaping,
and error-mapping logic here is unit-testable without google libraries.
"""
from __future__ import annotations

import time

from . import oauth
from .errors import CueError, UsageError, grpc_status_to_exit

ENDPOINT = "embeddedassistant.googleapis.com:443"
DEFAULT_TIMEOUT = 15.0


def build_request(text, model_id, device_id, lang_code="en-US", lat=None, lng=None):
    """Build a plain-dict description of the AssistRequest (text passed verbatim)."""
    return {
        "text_query": text,
        "device_model_id": model_id,
        "device_id": device_id,
        "lang_code": lang_code,
        "lat": lat,
        "lng": lng,
    }


def result_json(query, response_text, latency_ms, request_id, model_id, device_id):
    return {
        "query": query,
        "response_text": response_text,
        "latency_ms": latency_ms,
        "request_id": request_id,
        "model_id": model_id,
        "device_id": device_id,
    }


def _assist(creds, request, timeout):  # pragma: no cover - needs google libs/network
    """Open a gRPC channel and run one text query. Seam: patched in tests.

    Lazy-imports the Assistant SDK so this module loads without google libraries.
    """
    import google.auth.transport.grpc  # type: ignore
    import google.auth.transport.requests  # type: ignore
    from google.oauth2.credentials import Credentials  # type: ignore
    from google.assistant.embedded.v1alpha2 import (  # type: ignore
        embedded_assistant_pb2 as pb,
        embedded_assistant_pb2_grpc as pb_grpc,
    )

    c = Credentials(**{k: v for k, v in creds.items() if not k.startswith("_")})
    http_request = google.auth.transport.requests.Request()
    channel = google.auth.transport.grpc.secure_authorized_channel(c, http_request, ENDPOINT)
    assistant = pb_grpc.EmbeddedAssistantStub(channel)

    config = pb.AssistConfig(
        text_query=request["text_query"],
        audio_out_config=pb.AudioOutConfig(
            encoding=pb.AudioOutConfig.LINEAR16, sample_rate_hertz=16000, volume_percentage=0
        ),
        # Request a screen render so we get the response as text/HTML, not audio-only.
        screen_out_config=pb.ScreenOutConfig(screen_mode=pb.ScreenOutConfig.PLAYING),
        dialog_state_in=pb.DialogStateIn(language_code=request["lang_code"]),
        device_config=pb.DeviceConfig(
            device_id=request["device_id"], device_model_id=request["device_model_id"]
        ),
    )
    texts = []
    html_chunks = []
    for resp in assistant.Assist(iter([pb.AssistRequest(config=config)]), timeout):
        if resp.dialog_state_out.supplemental_display_text:
            texts.append(resp.dialog_state_out.supplemental_display_text)
        if resp.screen_out.data:
            html_chunks.append(resp.screen_out.data)
    text = "".join(texts)
    if not text and html_chunks:
        html = b"".join(html_chunks).decode("utf-8", "replace")
        text = _html_to_text(html)
    return text


def _html_to_text(html):
    """Extract visible answer text from an Assistant screen-out HTML card.

    The card embeds large <style>/<script> blocks; strip those first, then tags,
    then collapse whitespace. Returns the human-readable answer.
    """
    import re

    html = re.sub(r"(?is)<(script|style)\b[^>]*>.*?</\1>", " ", html)
    html = re.sub(r"(?s)<[^>]+>", " ", html)
    html = re.sub(r"&nbsp;", " ", html)
    html = re.sub(r"&amp;", "&", html)
    return re.sub(r"\s+", " ", html).strip()


def _map_rpc_error(exc):
    """If exc looks like a grpc.RpcError, raise the mapped CueError; else None."""
    code = getattr(exc, "code", None)
    if not callable(code):
        return None
    try:
        name = code().name
    except Exception:  # noqa: BLE001
        return None
    raise CueError(f"Assistant gRPC error: {name}", exit_code=grpc_status_to_exit(name)) from exc


def send_text_query(text, model_id, device_id, *, lang_code="en-US",
                    lat=None, lng=None, timeout=DEFAULT_TIMEOUT, creds=None):
    """Send one text query, return the Assistant's text response.

    Maps gRPC failures to documented exit codes via the exception's status name.
    """
    if not text:
        raise UsageError("empty query")
    if creds is None:
        creds = oauth.ensure_credentials()
    request = build_request(text, model_id, device_id, lang_code, lat, lng)
    try:
        return _assist(creds, request, timeout)
    except CueError:
        raise
    except Exception as exc:  # noqa: BLE001
        _map_rpc_error(exc)  # raises a mapped CueError if recognisable
        raise CueError(f"Assistant call failed: {exc}") from exc


def query_with_timing(text, model_id, device_id, **kwargs):
    """send_text_query plus latency measurement, for --json output (CUE-G-20)."""
    start = time.monotonic()
    response = send_text_query(text, model_id, device_id, **kwargs)
    latency_ms = int((time.monotonic() - start) * 1000)
    return response, latency_ms
