"""Compatibility handling for Work IQ OAuth consent responses.

Microsoft Foundry drives the on-behalf-of-the-signed-in-user OAuth flow for the Work IQ
toolbox. Work IQ emits its consent request as an ``a2a_preview`` error, which the current
Microsoft Agent Framework host build doesn't recognize; this shim teaches the host to
surface the consent URL so the Playground can prompt the user to consent once.
"""

import json

from agent_framework_foundry_hosting import _responses
from mcp import McpError

_original_consent_url_from_error = _responses.consent_url_from_error


def _consent_url_from_error(exc: BaseException) -> list[_responses.ConsentError] | None:
    consent_errors = _original_consent_url_from_error(exc)
    if consent_errors is not None:
        return consent_errors

    inner_exception = next((arg for arg in exc.args if isinstance(arg, McpError)), None)
    if inner_exception is None or inner_exception.error.code != _responses.CONSENT_ERROR_CODE:
        return None

    error_message_start = inner_exception.error.message.find("{")
    if error_message_start == -1:
        return None

    try:
        details = json.loads(inner_exception.error.message[error_message_start:])
    except json.JSONDecodeError:
        return None

    errors = details.get("errors")
    if not isinstance(errors, list):
        return None

    consent_errors = []
    for error in errors:
        if not isinstance(error, dict) or error.get("type") != "a2a_preview":
            continue
        error_details = error.get("error")
        if not isinstance(error_details, dict) or error_details.get("code") != "CONSENT_REQUIRED":
            continue
        consent_url = error_details.get("message")
        if isinstance(consent_url, str):
            consent_errors.append(
                _responses.ConsentError(
                    name=str(error.get("name", "Work IQ")),
                    consent_url=consent_url,
                )
            )
    return consent_errors or None


def enable_work_iq_consent_handling() -> None:
    """Teach the MAF host to emit consent requests for Work IQ A2A tools."""
    _responses.consent_url_from_error = _consent_url_from_error
