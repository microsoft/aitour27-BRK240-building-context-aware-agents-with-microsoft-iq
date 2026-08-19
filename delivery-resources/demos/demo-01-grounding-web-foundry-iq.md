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
| **Chat** with the agent | **VS Code — Foundry Toolkit** |
| **Show** the agent + the knowledge base | **Microsoft Foundry portal** |

> Why the Toolkit for chat? Our agent is published to Teams, so the Foundry portal's
> inline Playground is disabled for it. The Foundry Toolkit talks to the same agent
> endpoint and is the supported way to chat with a hosted agent. We use the Foundry
> **portal** only to *show* things (the agent and its knowledge base), not to chat.

## Before you start

> New environment? Do the [setup](../../docs/setup.md) first (prerequisites + deploy + seed).

- Agent `caldova-supply-autopilot` (version **v29**) is deployed and healthy.
- Knowledge base `caldova-supply-kb` exists with its four sources: **policies**,
  **procurement**, **quality**, **cold-chain**.
- VS Code is open with the Foundry Toolkit signed in.

---

## Steps

### Part A — Show the agent (Foundry portal)

1. Open the **Foundry portal** → **Agents** → **`caldova-supply-autopilot`**.
2. Point out it's a **hosted** agent on **version 29**.
3. Open its **connections / tools** and show that **Web IQ** and **Foundry IQ** are
   already wired in.
   > "This agent already has the live web and an enterprise knowledge base connected —
   > I didn't write any retrieval code."

### Part B — Ask a Web IQ question (Foundry Toolkit)

4. Switch to **VS Code → Foundry Toolkit** and open the chat with
   `caldova-supply-autopilot`. This is where you chat for the rest of the demo.
5. Ask:
   > Any weather or carrier disruptions this week that could affect cold-chain shipments?
6. The answer comes back with **current, real-world events** (storms, carrier delays)
   and **names its sources**. Point out it's grounded in the live web — and dated to
   **this week**, which no stored data could produce.

### Part C — Show the knowledge base (Foundry portal)

7. Switch back to the **Foundry portal** → **Knowledge bases** → open
   **`caldova-supply-kb`**.
   > This is the "what is it grounded in?" moment — make sure to show it.
8. Show its **four knowledge sources**: **policies**, **procurement & contracts**,
   **supplier quality & compliance**, and **cold-chain evidence**.
   > "It's not one big pile of PDFs — it's four organized sources the agent can cite."

### Part D — Ask a Foundry IQ question (Foundry Toolkit)

9. Back in the **Foundry Toolkit** chat, ask a document question:
   > Is a major cold-chain excursion eligible for replacement and credit?
10. The answer is grounded in the policy source and **cites the document**.
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
- The audience sees the knowledge base and its four sources in the Foundry portal.

## Talk track

> "Two very different questions — one about the outside world, one buried in a policy
> document — answered by the *same* agent, each grounded and cited. Web IQ gives it the
> live web; Foundry IQ gives it Caldova's own documents as a knowledge base. I didn't
> write any retrieval code — I connected knowledge, not plumbing."

## Voice-over script

> Read naturally, narrating what's on screen. ~2 minutes.

"Agents are only as good as the context they're given. So let me show you an agent
that's grounded in two very different kinds of context — with no retrieval code from me.

This is the Caldova Supply Autopilot, running in Microsoft Foundry. It's a hosted
agent, and if I open its connections, you can see it already has **Web IQ** and
**Foundry IQ** wired in — the live web, and an enterprise knowledge base.

Let me chat with it. I'll ask about the outside world first: *'Any weather or carrier
disruptions this week that could affect cold-chain shipments?'* Watch — it comes back
with current events: storms, a carrier advisory, and notice it names its sources, and
it's dated to this week. That's **Web IQ** — live information no internal system could
have.

Now, where does its *internal* knowledge come from? Let me show you. Back in Foundry,
under Knowledge bases, this is `caldova-supply-kb`. It's not one big pile of PDFs —
it's four organized sources: policies, procurement and contracts, supplier quality, and
cold-chain evidence.

So let me ask a question that lives inside those documents: *'Is a major cold-chain
excursion eligible for replacement and credit?'* And there it is — a grounded answer,
straight from Caldova's own policy, with a citation to the document.

Two completely different questions — the live web and a policy buried in a PDF —
answered by the same agent, each one grounded and cited. I didn't write any search
code. I connected knowledge, not plumbing. That's Web IQ and Foundry IQ."

## Transcript

_After recording, paste the final timed transcript here (also lives in the deck speaker notes)._
