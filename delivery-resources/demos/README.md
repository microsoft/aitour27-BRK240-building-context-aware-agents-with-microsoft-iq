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
| **Fabric IQ** | Numbers: supplier OTIF, quality, regulatory, audit, financial | Demo 2 |
| **Work IQ** | The mailbox (read + reply) | Demo 3 |

The clean boundary — **numbers → Fabric IQ, documents → Foundry IQ** — is enforced in
the agent's instructions so each question routes to exactly one source.

## Demos

| # | Demo | What it shows | Starts in |
|---|---|---|---|
| 1 | [Grounding with enterprise knowledge](demo-01-grounding-web-foundry-iq.md) | Chat with the deployed agent (Toolkit); Web IQ live context + Foundry IQ knowledge base (sources + index shown in the Foundry portal) | VS Code Foundry Toolkit + Foundry portal |
| 2 | [Business data with Fabric IQ](demo-02-fabric-iq.md) | Fabric workspace, ontology, Data Agent + instructions, and how the agent wires to it in code | Microsoft Fabric |
| 3 | [All four IQs as a governed teammate](demo-03-all-iqs-teams-governance.md) | Work IQ in Foundry, the full flow in Teams, the email proof in Outlook, and Agent 365 governance in the admin center | Microsoft Foundry → Teams → Admin center |

## Before any demo — set up the environment

All three demos assume the agent is already deployed and the four IQs are seeded.
If you're starting from scratch, do the setup first:

- **Prerequisites + deploy:** [`../../docs/setup.md`](../../docs/setup.md)
- **Attendee quickstart (build → deploy → try it):** [`../../instructions/README.md`](../../instructions/README.md)
- **Seeding + one-command `azd up`:** [`../../infra/README.md`](../../infra/README.md)

## Global pre-demo checklist (T-10 min)

- [ ] Agent is on the intended version (currently **v29**, `@latest`).
- [ ] **Warm up Fabric IQ**: ask the Data Agent one OTIF question so the first
      NL2SQL call in the demo isn't a cold start.
- [ ] All four IQ connections healthy: Web IQ, Foundry IQ (`caldova-supply-kb`),
      Fabric IQ (`caldova-supply-dataagent` → `SupplierDataAgent`), Work IQ.
- [ ] The autopilot is hired in Teams and reachable (send it a quick `hi`).
- [ ] A seeded **escalation email** (Maria Garcia) is **unread** in the *agent's*
      mailbox (not your personal mailbox).
- [ ] Tabs pre-opened: Foundry agent page, VS Code + Foundry Toolkit, Fabric
      workspace, Teams chat, the agent's Outlook, Microsoft 365 admin center.

## Delivery notes

- Ask questions **one at a time** and keep each **single-intent**. Compound
  Fabric questions ("same region *and* an issue") can error — split them.
- Each demo file has an **Instructions** (click-by-click) section and a
  **Transcript** placeholder — paste the transcript from your recording there.
- Recording links go in the table above and in each demo file's header.
