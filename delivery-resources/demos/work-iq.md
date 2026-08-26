# Demo 4 — Work IQ (Microsoft Foundry portal Playground)

> Recording: _add link_ · Target length: ~3–4 min

## What this demo shows

The Foundry Hosted Agent reads a **real mailbox** through **Work IQ** — **on-behalf-of
the signed-in user** — right in the Playground. You see Work IQ fire in **Traces**, open
the actual email, then show the code that attaches Work IQ and mints the user token.

## Where the demo happens

| You will… | In… |
|---|---|
| **Chat** the agent + show **Traces** | Microsoft Foundry portal — Playground |
| **Show** the real email | Outlook (your mailbox) |
| **Show** the code | VS Code — `src/foundry-hosted-agent/src/main.py` + `obo.py` |

## Before you start

- `caldova-supply-hosted-agent` is deployed with **on-behalf-of-user OBO** enabled.
- A cold-chain escalation email (from **Maria Garcia**) is in the signed-in user's mailbox.

---

## Steps

1. **Playground** — ask:
   > Any urgent supply escalations in my mailbox?

   It finds **Maria Garcia's** escalation — SHP-1234 (Alvexa).
2. Open **Traces** → show the **Work IQ** tool call. Call out that it's reading
   **your** mailbox — the agent is acting **on-behalf-of you**, so it only sees what
   you're allowed to see.
3. **Outlook** → open the same escalation email — "that's the message it just surfaced."
4. **VS Code:**
   - `src/foundry-hosted-agent/src/main.py` (**L116–129**) → `# 4) Work IQ` →
     `client.get_mcp_tool(name="Work IQ", headers={…user token…})` — "Work IQ acts as
     the signed-in user."
   - `src/foundry-hosted-agent/src/obo.py` (**`AgenticOboClient` / `token_for`**) → the
     agentic **on-behalf-of** exchange that mints the user's token for Work IQ.

## Questions used

| Ask | Source |
|---|---|
| Any urgent supply escalations in my mailbox? | Work IQ (read) |
| (alt) Summarize the most recent cold-chain escalation in my mailbox. | Work IQ (read) |

## Transcript

_Add the final voice-over transcript here after recording._
