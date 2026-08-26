# Demo flows — Caldova Supply, four Microsoft IQs

Five live demos build one story across all four Microsoft IQs on **Caldova
Pharmaceuticals'** own supplier, contract, policy, and web context. Demos 1–4 run in
the **Microsoft Foundry portal Playground** on the native **Foundry Hosted Agent**
(`caldova-supply-hosted-agent`) — one Microsoft IQ each, always the same beat:
**ask → Traces → the IQ's own surface → the code**. Demo 5 runs the **Agent 365
autopilot** (`caldova-supply-autopilot`) as a governed teammate in Microsoft Teams.
The two are independent agents.

> **Scenario.** Caldova is qualifying contract manufacturers (CMOs) and handling a
> cold-chain escalation. The autopilot reads the mailbox, ranks suppliers on real
> performance data, grounds decisions in Caldova policy and contracts, checks the
> web for disruptions, and replies — all under a governed agent identity that
> reports to its owner.

## The four IQs (and who owns what)

| IQ | Owns | Surface in these demos |
|---|---|---|
| **Web IQ** | Real-world context (weather, carrier, news) | Demo 1 |
| **Foundry IQ** | Documents: policies, contracts, quality/inspection reports | Demo 2 |
| **Fabric IQ** | Numbers *and* relationships: supplier OTIF, quality, regulatory, audit, financial — plus the medicinal-product ontology (products, substances, manufacturers, authorizations) | Demo 3 |
| **Work IQ** | The mailbox (read + reply) | Demo 4 (Playground) + Demo 5 (Teams) |

The clean boundary — **numbers → Fabric IQ, documents → Foundry IQ** — is enforced in
the agent's instructions so each question routes to exactly one source.

## Demos

| # | Demo | What it shows | Starts in |
|---|---|---|---|
| 1 | [Web IQ](web-iq.md) | Live-web grounding; Web IQ in **Traces**, the MCP surface, and the code | Microsoft Foundry portal Playground |
| 2 | [Foundry IQ](foundry-iq.md) | Cited policy answer; Foundry IQ in **Traces**, the knowledge base, and the code | Microsoft Foundry portal Playground |
| 3 | [Fabric IQ](fabric-iq.md) | Numbers *and* the medicinal-product ontology via the Data Agent; **Traces**, the Fabric workspace, and the code | Microsoft Fabric + Playground |
| 4 | [Work IQ](work-iq.md) | Reads your real mailbox **on-behalf-of you**; Work IQ in **Traces**, Outlook, and the OBO code | Microsoft Foundry portal Playground |
| 5 | [All four IQs + the autopilot](all-4-iqs-autopilot.md) | The governed autopilot in Teams — its own identity, all four IQs, replies from its mailbox, admin governance | Microsoft Teams → Admin center |

## Before any demo — set up the environment

All five demos assume the agents are deployed and the four Microsoft IQs are seeded.
If you're starting from scratch, do the setup first:

- **Foundry Hosted Agent (Playground) — deploy:** [`../../src/foundry-hosted-agent/README.md`](../../src/foundry-hosted-agent/README.md)
- **Autopilot (Teams) — prerequisites + deploy:** [`../../docs/setup.md`](../../docs/setup.md)
- **Attendee quickstart (build → deploy → try it):** [`../../instructions/README.md`](../../instructions/README.md)
- **Seeding + one-command `azd up`:** [`../../infra/README.md`](../../infra/README.md)

## Global pre-demo checklist (T-10 min)

- [ ] `caldova-supply-hosted-agent` is on `@latest` in the Playground (Demos 1–4);
      `caldova-supply-autopilot` is hired in Teams (Demo 5).
- [ ] **Warm up Fabric IQ — both sources**: ask one OTIF question and one ontology
      question ("Which medicinal products contain Caldovexine?") so neither cold-starts
      on stage. *(The ontology graph can time out on a cold first call — keep ontology
      questions single-hop.)*
- [ ] All four IQ connections healthy: Web IQ, Foundry IQ (`caldova-supply-kb`),
      Fabric IQ (`caldova-supply-dataagent` → `SupplierDataAgent`, attached to both
      `SupplierSM` and `CaldovaMedicinalProductOntology`), Work IQ.
- [ ] The autopilot is hired in Teams and reachable (send it a quick `hi`).
- [ ] A seeded **escalation email** (Maria Garcia) is **unread** in the *agent's*
      mailbox (not your personal mailbox).
- [ ] Tabs pre-opened: Foundry agent page + Playground + Traces, Fabric
      workspace, Teams chat, the agent's Outlook, Microsoft 365 admin center.

## Delivery notes

- Ask questions **one at a time** and keep each **single-intent**. Compound
  Fabric questions ("same region *and* an issue") can error — split them.
- Each demo file has an **Instructions** (click-by-click) section and a **Transcript**
  placeholder for the final cut.
- Recording links go in the table above and in each demo file's header.

### Code to show on camera (open these in VS Code before recording)

Some beats mean switching to the editor, not just clicking in a portal:

| Demo | File to open | What to point at |
|---|---|---|
| **all IQs** | `src/foundry-hosted-agent/infra/scripts/create-toolbox.ps1` | the **one toolbox** (`caldova-supply-tools`) bundling Fabric IQ (Data Agent MCP) + Work IQ + Foundry IQ + Web IQ, all as MCP tools |
| **all IQs** | `src/foundry-hosted-agent/src/main.py` | the whole agent = a **single `FoundryToolbox`** reference (Microsoft Foundry runs it with auth passthrough) |
| **3 — Fabric IQ** | `src/foundry-hosted-agent/src/instructions.md` | the routing rule: numbers → Fabric IQ, documents → Foundry IQ |
| **4 — Work IQ** | `create-toolbox.ps1` → the `workiq` tool | the `UserEntraToken` connection → Work IQ resolves as the signed-in you |
| **5 — autopilot** | `src/autopilot/instructions.md` (Email section) | how the autopilot is told to reply via Work IQ |

Keep the repo open in VS Code alongside the Microsoft Foundry portal Playground so these switches are quick.


