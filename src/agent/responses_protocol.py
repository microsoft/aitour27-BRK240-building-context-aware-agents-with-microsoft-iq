# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

"""OpenAI-compatible ``/responses`` endpoint for the Foundry portal Playground.

The Foundry portal Playground can only chat with a hosted agent that serves the
**Responses protocol** (the OpenAI-compatible ``/responses`` endpoint). Our
container primarily serves the **activity protocol** (``/api/messages``) for
Microsoft Teams / Agent 365. This module adds a ``/responses`` route to the SAME
aiohttp app so the agent can be tested in the Foundry Playground WITHOUT a
separate "twin" agent.

Design notes:

* **Additive only.** The Teams/activity path (``/api/messages``) is untouched.
* **App-identity IQ path.** The Playground has no signed-in Teams user, so this
  endpoint runs the agent's existing *app-identity* path (``auth=None``,
  ``context=None``). Under app identity only **Web IQ** and **Foundry IQ**
  resolve; **Work IQ** and **Fabric IQ** need user-delegated OBO and remain
  available on the Teams activity path. That is exactly what demo 2 (grounding
  with Web IQ + Foundry IQ) needs.
* **Stateless.** Each call uses a fresh conversation id, so Playground turns do
  not bleed into each other or into Teams sessions.

The SSE event lifecycle mirrors the Foundry Responses protocol:
``response.created`` -> ``response.in_progress`` ->
``response.output_item.added`` -> ``response.content_part.added`` ->
``response.output_text.delta`` -> ``response.output_text.done`` ->
``response.content_part.done`` -> ``response.output_item.done`` ->
``response.completed``.
"""

from __future__ import annotations

import json
import logging
import time
import uuid
from typing import Any, Callable

from aiohttp.web import Request, StreamResponse, json_response

logger = logging.getLogger("responses_protocol")


def _extract_input_text(body: dict[str, Any]) -> str:
    """Pull the user text out of an OpenAI Responses request body.

    Accepts ``input`` as a plain string, a list of message items, or a list of
    content parts.
    """
    inp = body.get("input", "")
    if isinstance(inp, str):
        return inp
    texts: list[str] = []
    if isinstance(inp, list):
        for item in inp:
            if isinstance(item, str):
                texts.append(item)
            elif isinstance(item, dict):
                content = item.get("content")
                if isinstance(content, str):
                    texts.append(content)
                elif isinstance(content, list):
                    for seg in content:
                        if isinstance(seg, dict):
                            t = seg.get("text")
                            if isinstance(t, str):
                                texts.append(t)
    return "\n".join(t for t in texts if t)


def _message_item(msg_id: str, text: str, status: str) -> dict[str, Any]:
    return {
        "id": msg_id,
        "type": "message",
        "status": status,
        "role": "assistant",
        "content": [{"type": "output_text", "text": text, "annotations": []}],
    }


def _response_obj(
    resp_id: str, model: str, status: str, output: list[dict[str, Any]], created: int
) -> dict[str, Any]:
    return {
        "id": resp_id,
        "object": "response",
        "created_at": created,
        "status": status,
        "model": model,
        "output": output,
        "error": None,
        "metadata": {},
    }


def _sse_frame(event_type: str, payload: dict[str, Any]) -> bytes:
    return f"event: {event_type}\ndata: {json.dumps(payload)}\n\n".encode("utf-8")


def build_responses_handler(get_agent: Callable[[], Any]):
    """Return an aiohttp handler for ``POST /responses``.

    ``get_agent`` returns the initialized agent instance (or ``None`` before
    startup completes).
    """

    async def handler(req: Request) -> Any:
        try:
            body = await req.json()
        except Exception:
            body = {}

        agent = get_agent()
        if agent is None:
            return json_response(
                {"error": {"message": "agent not initialized"}}, status=503
            )

        user_text = _extract_input_text(body if isinstance(body, dict) else {})
        if not user_text.strip():
            return json_response(
                {"error": {"message": "no input provided"}}, status=400
            )

        stream = bool(body.get("stream", False)) or (
            "text/event-stream" in (req.headers.get("Accept", "") or "")
        )

        resp_id = f"resp_{uuid.uuid4().hex}"
        msg_id = f"msg_{uuid.uuid4().hex}"
        model = getattr(agent, "_deployment", "") or ""
        created = int(time.time())
        instructions = agent.AGENT_PROMPT.replace("{user_name}", "there")

        logger.info("Playground /responses turn: %s", user_text[:200])
        try:
            # App-identity path (Web IQ + Foundry IQ). Fresh conversation id so
            # Playground turns are independent and never touch Teams sessions.
            text = await agent._invoke_responses_api(
                input_text=user_text,
                conversation_id=f"foundry-playground-{uuid.uuid4().hex}",
                instructions=instructions,
                auth=None,
                auth_handler_name=None,
                context=None,
            )
        except Exception as ex:  # noqa: BLE001
            logger.exception("responses handler failed")
            text = f"Sorry, I ran into an error: {ex}"
        text = text or "Done."

        if not stream:
            obj = _response_obj(
                resp_id, model, "completed",
                [_message_item(msg_id, text, "completed")], created,
            )
            obj["output_text"] = text
            return json_response(obj)

        sr = StreamResponse(
            status=200,
            headers={
                "Content-Type": "text/event-stream",
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
            },
        )
        await sr.prepare(req)
        seq = 0

        async def emit(event_type: str, extra: dict[str, Any]) -> None:
            nonlocal seq
            payload = {"type": event_type, "sequence_number": seq, **extra}
            seq += 1
            await sr.write(_sse_frame(event_type, payload))

        in_progress = _response_obj(resp_id, model, "in_progress", [], created)
        await emit("response.created", {"response": in_progress})
        await emit("response.in_progress", {"response": in_progress})
        await emit(
            "response.output_item.added",
            {"output_index": 0, "item": _message_item(msg_id, "", "in_progress")},
        )
        await emit(
            "response.content_part.added",
            {
                "item_id": msg_id,
                "output_index": 0,
                "content_index": 0,
                "part": {"type": "output_text", "text": "", "annotations": []},
            },
        )
        await emit(
            "response.output_text.delta",
            {"item_id": msg_id, "output_index": 0, "content_index": 0, "delta": text},
        )
        await emit(
            "response.output_text.done",
            {"item_id": msg_id, "output_index": 0, "content_index": 0, "text": text},
        )
        await emit(
            "response.content_part.done",
            {
                "item_id": msg_id,
                "output_index": 0,
                "content_index": 0,
                "part": {"type": "output_text", "text": text, "annotations": []},
            },
        )
        completed_item = _message_item(msg_id, text, "completed")
        await emit(
            "response.output_item.done",
            {"output_index": 0, "item": completed_item},
        )
        completed = _response_obj(
            resp_id, model, "completed", [completed_item], created
        )
        completed["output_text"] = text
        await emit("response.completed", {"response": completed})
        await sr.write_eof()
        return sr

    return handler
