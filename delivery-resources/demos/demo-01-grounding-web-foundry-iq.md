# Demo 1 — Grounding with enterprise knowledge (Web IQ + Foundry IQ)

> Recording: _add link_ · Target length: ~4–5 min

## What this demo shows

One deployed agent answers two very different questions — one about the **outside
world**, one buried in an **internal policy document** — and grounds each one
correctly, with no custom search code:

- **Web IQ** gives the agent the live web.
- **Foundry IQ** gives it Caldova's own documents as a searchable knowledge base.

## Where the demo happens

| You will… | In… |
|---|---|
| **Chat** with the agent | **Microsoft Foundry portal — Playground** |
| **Show** the agent, the knowledge base, and **Traces** | **Microsoft Foundry portal** |

> This is the native Foundry Hosted Agent `caldova-supply-hosted-agent` — it is not published
> to Teams, so you chat with it right in the portal **Playground**, and each IQ call
> shows up in the **Traces** tab. (The Teams autopilot is a separate agent, used in
> Demo 3.)

## Before you start

> New environment? Do the [setup](../../docs/setup.md) first (prerequisites + deploy + seed).

- Agent `caldova-supply-hosted-agent` is deployed and healthy in the Foundry project.
- Knowledge base `caldova-supply-kb` exists with its four sources: **policies**,
  **procurement**, **quality**, **cold-chain**.
- You're signed into the Microsoft Foundry portal.

---

## Steps

### Part A — Show the agent (Microsoft Foundry portal)

1. Open the **Microsoft Foundry portal** → **Agents** → **`caldova-supply-hosted-agent`**.
2. Point out it's a **native hosted** agent, chattable right here in the **Playground**.
3. Open its **connections / tools** and show that **Web IQ** and **Foundry IQ** are
   already wired in.
   > "This agent already has the live web and an enterprise knowledge base connected —
   > I didn't write any retrieval code."

### Part B — Ask a Web IQ question (Playground)

4. In the **Microsoft Foundry portal Playground** for `caldova-supply-hosted-agent`, ask:
   > Any weather or carrier disruptions this week that could affect cold-chain shipments?
5. The answer comes back with **current, real-world events** (storms, carrier delays)
   and **names its sources**. Point out it's grounded in the live web — and dated to
   **this week**, which no stored data could produce.
6. Open the **Traces** tab and show the **Web IQ** tool call.

### Part C — Show the knowledge base (Microsoft Foundry portal)

7. Switch back to the **Microsoft Foundry portal** → **Knowledge bases** → open
   **`caldova-supply-kb`**.
   > This is the "what is it grounded in?" moment — make sure to show it.
8. Show its **four knowledge sources**: **policies**, **procurement & contracts**,
   **supplier quality & compliance**, and **cold-chain evidence**.
   > "It's not one big pile of PDFs — it's four organized sources the agent can cite."

### Part D — Ask a Foundry IQ question (Playground)

9. Back in the **Playground**, ask a document question:
   > Is a major cold-chain excursion eligible for replacement and credit?
10. The answer is grounded in the policy source and **cites the document**. Open
    **Traces** and show the **Foundry IQ** call.
11. *(Optional)* Show it can reach a different source:
    > Why was Summit Dose awarded CALD-201?

---

## Questions used

| Ask | Grounded by |
|---|---|
| Any weather or carrier disruptions this week that could affect cold-chain shipments? | Web IQ |
| Is a major cold-chain excursion eligible for replacement and credit? | Foundry IQ (policies) |
| Why was Summit Dose awarded CALD-201? | Foundry IQ (procurement) |

## How to prove each IQ fired

Each answer includes **inline source markers** — Web IQ tags its web sources (e.g.
`CBS News`, `CSX.com`), and Foundry IQ cites the knowledge-base documents. They look
raw/compact, but they're your on-screen proof:

> "Notice the answer names its sources — that's Web IQ and Foundry IQ grounding it,
> not the model guessing."

Web IQ's answer is also **dated to this week**, which only the live web could give you.

## What success looks like

- The web question returns **current** events with **Web IQ** source tags.
- The policy question returns a **grounded, cited** answer from the knowledge base.
- The audience sees the knowledge base and its four sources in the Microsoft Foundry portal.

## Talk track

> "Two very different questions — one about the outside world, one buried in a policy
> document — answered by the *same* agent, each grounded and cited. Web IQ gives it the
> live web; Foundry IQ gives it Caldova's own documents as a knowledge base. I didn't
> write any retrieval code — I connected knowledge, not plumbing."

## Transcript

_After recording, paste the final timed transcript here (also lives in the deck speaker notes)._
