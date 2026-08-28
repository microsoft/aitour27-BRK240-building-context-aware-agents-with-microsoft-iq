# Delivery Resources

## How to deliver this session

🥇 Thanks for delivering this session!

Presenter and train-the-trainer materials for **BRK240 — Building context-aware agents with
the Microsoft IQ platform**. The demo follows **Caldova Pharmaceuticals**, a fictional global
pharmaceutical company, as its supply-assurance analyst handles a cold-chain escalation and
grounds every decision across the four Microsoft IQs — Web IQ, Foundry IQ, Fabric IQ, and
Work IQ.

Before you deliver the session, please:

1. Read this document and every linked resource in full.
2. Watch the full session recording and the per-demo clips.
3. Open the delivery deck and review the Caldova supply-assurance storyline.
4. Set up the environment end to end (see the **Prepare Your Environment** section below),
   then validate it: both agents deployed, all four Microsoft IQ connections healthy, the
   Caldova content seeded (Foundry IQ knowledge base and Fabric IQ), and the demo mailboxes
   seeded.
5. Warm up the Fabric Data Agent (semantic model and ontology) with one query each before
   going live.

## 📁 File Summary

| Resource | Link | Description |
|---|---|---|
| Session delivery deck | _add link_ | The session delivery slides (Caldova supply-assurance storyline) |
| Full session recording | _add link_ | The full session presentation |
| Demo flows | [demos/README.md](demos/README.md) | Five per-demo walkthroughs and prompts |
| Setup and deploy | [Prepare Your Environment](#-prepare-your-environment) | Full inline setup (also in [../docs/setup.md](../docs/setup.md)) |
| Attendee instructions | [../instructions/README.md](../instructions/README.md) | Start here for the guided path |

## 🖥️ Demo Videos

Select the demo instructions to see how to deliver each demo. Each demo has two clips: a
**clean capture** with no audio (for you to voice over live) and a **voice-over** version
with narration. The written run of show and prompts for each demo are in the linked
instructions.

| # | Demo | Instructions | Clip — no audio | Clip — voice-over |
|---|---|---|---|---|
| 1 | Web IQ | [Demo instructions](demos/web-iq.md) | [Demo - no audio](https://github.com/user-attachments/assets/87810d23-58c5-45c8-8a29-9b3d238a8b83) | [Demo - with audio](https://github.com/user-attachments/assets/d88e353a-232b-4add-a522-672920218b37) |
| 2 | Foundry IQ | [Demo instructions](demos/foundry-iq.md) | [Demo - no audio](https://github.com/user-attachments/assets/58deeeea-875b-4446-88d1-3672f92cfa48) | [Demo - with audio](https://github.com/user-attachments/assets/2b7bd491-5c01-44c4-a027-ad00ccbcd3b4) |
| 3 | Fabric IQ | [Demo instructions](demos/fabric-iq.md) | [Demo - no audio](https://github.com/user-attachments/assets/13272e5a-1076-4074-8a80-b9cb8832510f) | [Demo - with audio](https://github.com/user-attachments/assets/56e91971-3fa6-420f-a378-51223270ba64) |
| 4 | Work IQ | [Demo instructions](demos/work-iq.md) | [Demo - no audio](https://github.com/user-attachments/assets/4d3c27e2-bdca-4f6f-9908-55655a86e881) | [Demo - with audio](https://github.com/user-attachments/assets/576f6400-9062-4b71-a614-aa468fdbc7f0) |
| 5 | All four IQs + the autopilot | [Demo instructions](demos/all-4-iqs-autopilot.md) | [Demo - no audio](https://github.com/user-attachments/assets/f4b40b09-ec0c-494c-bf67-dfc6402a1b58) | [Demo - with audio](https://github.com/user-attachments/assets/78871168-b4a1-4408-9b20-1869f538ce90) |


## 🏋️ Prepare Your Environment

Everything needed to stand this demo up, in order. The scripts referenced here live in
the repo; the detailed reference for each step is linked inline. Set aside ~60–90 minutes
for a first run (Fabric provisioning and the Agent 365 hire are the slow parts).

### What these demos run on

Two agents over one set of Microsoft IQ connections:

- **Foundry Hosted Agent** (`caldova-supply-hosted-agent`) — used in **demos 1–4** in the
  Microsoft Foundry portal Playground. All four IQs come through **one Foundry toolbox**
  (`caldova-supply-tools`) that Microsoft Foundry runs with **auth passthrough**, so
  Fabric IQ and Work IQ resolve as the **signed-in user**.
- **Agent 365 autopilot** (`caldova-supply-autopilot`) — used in **demo 5** in Microsoft Teams.
  It is a governed agent with its own Agent 365 identity and its own mailbox. You manage it in
  the Microsoft 365 admin center, and it works under its own identity, not yours.

### Prerequisites

**Accounts and licenses**

- An **Azure subscription** where you can create resources and assign roles (**Owner**, or
  **Contributor + User Access Administrator**).
- A **Microsoft 365 tenant** with **Agent 365** and **Microsoft 365 Copilot** licenses, enrolled
  in the [Frontier preview program](https://adoption.microsoft.com/en-us/copilot/frontier-program/).
  Demo 5 also needs a **Global Administrator** in that tenant to publish and approve the autopilot.
- A **Web IQ** private-preview key — Web IQ is not generally available yet.

**Tools** (install these first)

- [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) (`azd`)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) (`az`)
- [Python 3.11+](https://www.python.org/downloads/) and [uv](https://docs.astral.sh/uv/)
- [Visual Studio Code](https://code.visualstudio.com/)

**Have these ready before setup**

- Your **Web IQ preview key** → `WEB_IQ_API_KEY`.
- A **Microsoft Fabric workspace** and its id → `FABRIC_WORKSPACE_ID`.

### 1. Provision and build everything — `azd up`

From the repo root, run:

```bash
az login
azd auth login
azd env set FABRIC_WORKSPACE_ID <your-fabric-workspace-guid>
azd env set WEB_IQ_API_KEY <your-web-iq-preview-key>
azd up
```

This provisions the Azure resources (Microsoft Foundry, Container Registry, Azure AI Search,
and a Fabric capacity), then builds the rest: the Fabric data, the four Microsoft IQ
connections, the toolbox, the Foundry Hosted Agent, the autopilot, and the demo emails.

> **If an ontology question hangs (~5 minutes) and fails**, refresh the ontology graph:
> run [`../infra/scripts/refresh-ontology-graph.py`](../infra/scripts/refresh-ontology-graph.py)
> (or in the portal, open the `…_graph` item → **… → Schedule → Refresh now**), then re-run
> the Data Agent step. See [`../docs/ontology.md`](../docs/ontology.md).

### 2. Finish the autopilot (admin-gated, demo 5)

`azd up` builds the autopilot container + version; the **Agent 365 registration** is a
separate admin step. As a **Global Administrator**: run
[`../infra/a365/publish-autopilot.ps1`](../infra/a365/publish-autopilot.ps1), approve the
blueprint in the admin center, and **hire an instance in Microsoft Teams**. Full walkthrough:
[`../docs/setup.md`](../docs/setup.md) and [`../instructions/README.md`](../instructions/README.md).

### 3. Seed the demo mailboxes

`azd up` seeds **your** mailbox. Seed the **agent's** mailbox after the autopilot is hired:

- **Your** mailbox (demo 4): **Priya Nair — SHP-9021 (Brightline Labs)**.
- **The agent's** mailbox (demo 5): **Maria Garcia — SHP-1234 (Alvexa)** — run
  [`../infra/hooks/seed-emails.ps1`](../infra/hooks/seed-emails.ps1) `-AgentMailbox <agent-upn>`
  after hiring.

### 4. Pre-flight checks (T-10 min, before recording)

- All four IQ connections healthy in the Foundry project.
- **Warm up Fabric IQ — both sources**: ask one OTIF question *and* one ontology question
  (e.g. "Which medicinal products contain Caldovexine?") so neither cold-starts on stage.
- Hosted agent reachable in the Playground; autopilot hired and responding in Microsoft Teams.
- After any redeploy, retire the old agent version so the Playground and Microsoft Teams roll to `@latest`.

## Support

Content owners / contacts: **Ayça Baş** (https://github.com/aycabas) and **Pamela Fox** (https://github.com/pamelafox)
