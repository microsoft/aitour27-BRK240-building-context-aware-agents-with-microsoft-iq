# Demo flows — Caldova Supply Autopilot

Three live demos build one story: a single **Agent 365 autopilot** grounded across
all four Microsoft IQs on **Caldova Pharmaceuticals'** own supplier, contract,
policy, and web context — then run as a governed teammate in Microsoft Teams.

> **Scenario.** Caldova is qualifying contract manufacturers (CMOs) and handling a
> cold-chain escalation. The autopilot reads the mailbox, ranks suppliers on real
> performance data, grounds decisions in Caldova policy and contracts, checks the
> web for disruptions, and replies — all under a governed agent identity that
> reports to its owner.

## The four IQs (and who owns what)

| IQ | Owns | Surface in these demos |
|---|---|---|
| **Web IQ** | Real-world context (weather, carrier, news) | Demo 1 |
| **Foundry IQ** | Documents: policies, contracts, quality/inspection reports | Demo 1 |
| **Fabric IQ** | Numbers *and* relationships: supplier OTIF, quality, regulatory, audit, financial — plus the medicinal-product ontology (products, substances, manufacturers, authorizations) | Demo 2 |
| **Work IQ** | The mailbox (read + reply) | Demo 3 |

The clean boundary — **numbers → Fabric IQ, documents → Foundry IQ** — is enforced in
the agent's instructions so each question routes to exactly one source.

## Demos

| # | Demo | What it shows | Starts in |
|---|---|---|---|
| 1 | [Grounding with enterprise knowledge](demo-01-grounding-web-foundry-iq.md) | Chat with the deployed agent (Toolkit); Web IQ live context + Foundry IQ knowledge base (sources + index shown in the Foundry portal) | VS Code Foundry Toolkit + Foundry portal |
| 2 | [Business data with Fabric IQ](demo-02-fabric-iq.md) | Fabric workspace, the medicinal-product ontology, Data Agent + instructions, a question that spans semantic model *and* ontology, and how the agent wires to it in code | Microsoft Fabric |
| 3 | [All four IQs as a governed teammate](demo-03-all-iqs-teams-governance.md) | Work IQ in Foundry, the full flow in Teams, the email proof in Outlook, and Agent 365 governance in the admin center | Microsoft Foundry → Teams → Admin center |

## Before any demo — set up the environment

All three demos assume the agent is already deployed and the four IQs are seeded.
If you're starting from scratch, do the setup first:

- **Prerequisites + deploy:** [`../../docs/setup.md`](../../docs/setup.md)
- **Attendee quickstart (build → deploy → try it):** [`../../instructions/README.md`](../../instructions/README.md)
- **Seeding + one-command `azd up`:** [`../../infra/README.md`](../../infra/README.md)

## Global pre-demo checklist (T-10 min)

- [ ] Agent is on the intended version (currently **v29**, `@latest`).
- [ ] **Warm up Fabric IQ — both sources**: ask one OTIF question *and* one ontology
      question ("Which active substances have only one approved manufacturer?") so
      neither cold-starts on stage.
- [ ] All four IQ connections healthy: Web IQ, Foundry IQ (`caldova-supply-kb`),
      Fabric IQ (`caldova-supply-dataagent` → `SupplierDataAgent`, attached to both
      `SupplierSM` and `CaldovaMedicinalProductOntology`), Work IQ.
- [ ] The autopilot is hired in Teams and reachable (send it a quick `hi`).
- [ ] A seeded **escalation email** (Maria Garcia) is **unread** in the *agent's*
      mailbox (not your personal mailbox).
- [ ] Tabs pre-opened: Foundry agent page, VS Code + Foundry Toolkit, Fabric
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
| Demo 1 *(optional)* | `src/agent/responses_protocol.py` | the `/responses` endpoint the Toolkit talks to |
| **Demo 2** | `src/agent/agent.py` → `_load_iq_tools` | Fabric IQ as one `fabric_dataagent_preview` tool reference |
| **Demo 2** | `src/agent/instructions.md` | the routing rule: numbers → Fabric IQ, documents → Foundry IQ |
| Demo 3 *(optional)* | `src/agent/instructions.md` (Email section) | how the agent is told to reply via Work IQ |

Keep the repo open in VS Code alongside the Foundry Toolkit so these switches are quick.
