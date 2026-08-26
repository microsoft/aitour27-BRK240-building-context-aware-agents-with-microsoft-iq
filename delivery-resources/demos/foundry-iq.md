# Demo 2 — Foundry IQ (Microsoft Foundry portal Playground)

> Recording: _add link_ · Target length: ~3–4 min

## What this demo shows

The same Foundry Hosted Agent answers a question buried in an **internal policy
document**, grounded and **cited** via **Foundry IQ** (a Microsoft Foundry knowledge
base over Azure AI Search) — then you show the knowledge base itself and the one line
of code that wires it in.

## Where the demo happens

| You will… | In… |
|---|---|
| **Chat** the agent + show **Traces** | Microsoft Foundry portal — Playground |
| **Show** the knowledge base | Microsoft Foundry portal — Knowledge bases |
| **Show** the code | VS Code — `src/foundry-hosted-agent/src/main.py` |

## Before you start

- `caldova-supply-hosted-agent` is deployed and healthy.
- Knowledge base `caldova-supply-kb` exists with its four sources: **policies**,
  **procurement**, **quality**, **cold-chain**.

---

## Steps

1. **Playground** — ask a document question:
   > Is a major cold-chain excursion eligible for replacement and credit?

   The answer is grounded in the policy source and **cites the document**.
2. Open **Traces** → show the **Foundry IQ** tool call.
3. **Show the knowledge base** — Microsoft Foundry portal → **Knowledge bases** →
   `caldova-supply-kb`. Walk its **four sources** (policies / procurement & contracts /
   supplier quality & compliance / cold-chain evidence).
   > "It's not one pile of PDFs — it's four organized sources the agent can cite."
4. **VS Code** → `src/foundry-hosted-agent/src/main.py` (**L90–101**) → `# 2) Foundry IQ`
   → `client.get_mcp_tool(name="Foundry IQ", …, project_connection_id="caldova-supply-kb")`.
5. *(optional)* Show it reaching a different source:
   > Why was Summit Dose awarded CALD-201?

## Questions used

| Ask | Source |
|---|---|
| Is a major cold-chain excursion eligible for replacement and credit? | Foundry IQ (policy) |
| (alt) Why was Summit Dose awarded CALD-201? | Foundry IQ (procurement) |

## Transcript

_Add the final voice-over transcript here after recording._
