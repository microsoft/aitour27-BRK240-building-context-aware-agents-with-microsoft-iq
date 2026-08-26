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
| **Show** the code | VS Code — `create-toolbox.ps1` + `src/foundry-hosted-agent/src/main.py` |

## Before you start

- `caldova-supply-hosted-agent` is deployed; the `caldova-supply-tools` toolbox carries
  Work IQ (auth passthrough → the signed-in user).
- A cold-chain escalation email (**Priya Nair — SHP-9021, Brightline Labs**) is in **your**
  mailbox. *(Seed it by mailing it to yourself; the agent's own mailbox has a separate one.)*

---

## Steps

1. **Playground** — ask:
   > Any urgent supply escalations in my mailbox?

   It finds **your** escalation — **SHP-9021 (Brightline Labs)** from **Priya Nair**.
   *(Or ask "Summarize my mails" to show it's reading your real inbox.)*
2. Open **Traces** → show the **Work IQ** tool call. Call out that it's reading
   **your** mailbox — the agent acts **on-behalf-of you**, so it only sees what you can.
3. **Outlook** → open the same escalation email — "that's the message it just surfaced."
4. **VS Code:**
   - `src/foundry-hosted-agent/infra/scripts/create-toolbox.ps1` → the **`workiq`** tool in
     the `caldova-supply-tools` toolbox, on the **`UserEntraToken`** connection.
   - `src/foundry-hosted-agent/src/main.py` → the single `FoundryToolbox`.
   > "Microsoft Foundry runs the toolbox with **auth passthrough** — no manual tokens; Work
   > IQ resolves as the signed-in you."

## Questions used

| Ask | Source |
|---|---|
| Any urgent supply escalations in my mailbox? | Work IQ (read) |
| (alt) Summarize the most recent cold-chain escalation in my mailbox. | Work IQ (read) |

## Transcript

_Add the final voice-over transcript here after recording._
