# Delivery Resources

Presenter and train-the-trainer materials for **BRK240 — Building context-aware agents with
Microsoft IQ platform** (FY27 Caldova, Chapter 01 "Ground").

## Delivery checklist

- Review the session [README](../README.md) and attendee [instructions](../instructions/README.md)
- Review the [demo flows](demos/README.md) (five per-demo run of show + prompts)
- Open the deck (Caldova FY27 storyline)
- Set up the environment top to bottom (see [Prepare your environment](#prepare-your-environment) below)
- Validate the environment: both agents deployed, all four IQ connections healthy, Caldova
  corpus seeded (Foundry IQ KB + Fabric IQ), demo mailboxes seeded
- Warm the Fabric Data Agent — both sources — with one query each before going live

## Core materials

| Item | Link | Notes |
|---|---|---|
| Delivery deck | _add link_ | Caldova FY27 storyline (Chapter 01 "Ground") |
| Full session recording | _add link_ | The full session presentation |
| Demo flows | [demos/README.md](demos/README.md) | Five per-demo walkthroughs + prompts |
| Setup / deploy | [Prepare your environment](#prepare-your-environment) | Full inline setup (also in [../docs/setup.md](../docs/setup.md)) |
| Attendee instructions | [../instructions/README.md](../instructions/README.md) | Start here for the guided path |

## Full session recording

The full session presentation. This breakout is divided into an intro, the five demos,
and a wrap-up. Add the recording link above, then fill the timings below after the final
cut.

## Demo recordings

One clip per demo, in two versions: a **clean capture** with no audio (for you to
voice over live) and a **voice-over** version with narration. The written run of show
and prompts for each demo are in the linked instructions.

| # | Demo | Instructions | Clip — no audio | Clip — voice-over |
|---|---|---|---|---|
| 1 | Web IQ | [Demo instructions](demos/web-iq.md) | [Demo - no audio](https://github.com/user-attachments/assets/87810d23-58c5-45c8-8a29-9b3d238a8b83) | [Demo - with audio](https://github.com/user-attachments/assets/d88e353a-232b-4add-a522-672920218b37) |
| 2 | Foundry IQ | [Demo instructions](demos/foundry-iq.md) | [Demo - no audio](https://github.com/user-attachments/assets/58deeeea-875b-4446-88d1-3672f92cfa48) | [Demo - with audio](https://github.com/user-attachments/assets/2b7bd491-5c01-44c4-a027-ad00ccbcd3b4) |
| 3 | Fabric IQ | [Demo instructions](demos/fabric-iq.md) | [Demo - no audio](https://github.com/user-attachments/assets/13272e5a-1076-4074-8a80-b9cb8832510f) | [Demo - with audio](https://github.com/user-attachments/assets/56e91971-3fa6-420f-a378-51223270ba64) |
| 4 | Work IQ | [Demo instructions](demos/work-iq.md) | [Demo - no audio](https://github.com/user-attachments/assets/4d3c27e2-bdca-4f6f-9908-55655a86e881) | [Demo - with audio](https://github.com/user-attachments/assets/576f6400-9062-4b71-a614-aa468fdbc7f0) |
| 5 | All four IQs + the autopilot | [Demo instructions](demos/all-4-iqs-autopilot.md) | [Demo - no audio](https://github.com/user-attachments/assets/f4b40b09-ec0c-494c-bf67-dfc6402a1b58) | [Demo - with audio](https://github.com/user-attachments/assets/78871168-b4a1-4408-9b20-1869f538ce90) |


## Prepare your environment

Everything needed to stand this demo up, in order. The scripts referenced here live in
the repo; the detailed reference for each step is linked inline. Set aside ~60–90 minutes
for a first run (Fabric provisioning and the Agent 365 hire are the slow parts).

### What this demo runs on

Two agents over one set of Microsoft IQ connections:

- **Foundry Hosted Agent** (`caldova-supply-hosted-agent`) — used in **demos 1–4** in the
  Microsoft Foundry portal Playground. All four IQs come through **one Foundry toolbox**
  (`caldova-supply-tools`) that Microsoft Foundry runs with **auth passthrough**, so
  Fabric IQ and Work IQ resolve as the **signed-in user**.
- **Agent 365 autopilot** (`caldova-supply-autopilot`) — used in **demo 5** in Microsoft
  Teams, as a governed digital worker that can also reply from its own mailbox.

### Prerequisites

**Accounts and licenses**

- An **Azure subscription** where you are **Owner**.
- A **Microsoft 365 tenant** with **Agent 365 + Microsoft Copilot** licenses, enrolled in
  the [Frontier preview program](https://adoption.microsoft.com/en-us/copilot/frontier-program/)
  (required to publish a Foundry agent to Agent 365).

**Pre-existing Azure/Fabric resources** (you bring these; `azd up` does not create them)

- **Azure AI Search** service — backs Foundry IQ.
- **Microsoft Fabric** workspace on an active **capacity** — backs Fabric IQ.
- A **Microsoft Foundry project** to hold the four IQ connections + a reasoning model
  deployment (e.g. `gpt-5.4-mini`).
- A **Web IQ** (`api.microsoft.ai`) subscription key.

**Tools**

- [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) (`azd`)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) (`az`)
- [Python 3.11+](https://www.python.org/downloads/) and [uv](https://docs.astral.sh/uv/)
- [Visual Studio Code](https://code.visualstudio.com/)

Full prerequisites and the two-project model: [`../docs/setup.md`](../docs/setup.md).

### 1. Provision the Fabric data

From [`../data/caldova-upstream/`](../data/caldova-upstream/) (Pamela Fox's canonical
Caldova dataset), create a `.env` with `FABRIC_TENANT_ID` and `FABRIC_WORKSPACE_ID`, sign
in (`azd auth login` / `az login`), then `uv sync`. Run the scripts in order:

```bash
uv run python provision/fabric/create_fabric_lakehouse.py
uv run python provision/fabric/create_fabric_ontology.py
# Build the ontology graph — REQUIRED, or ontology questions time out:
uv run python ../../infra/scripts/refresh-ontology-graph.py
uv run python provision/fabric/create_fabric_semantic_model.py
uv run python provision/fabric/create_fabric_reports.py
uv run python provision/fabric/create_fabric_data_agent.py
```

This creates the `CaldovaSupplierAnalytics` lakehouse, the `CaldovaMedicinalProductOntology`
ontology, the `SupplierSM` semantic model, a report, and the published `SupplierDataAgent`.
Details: [`../data/caldova-upstream/provision/fabric/README.md`](../data/caldova-upstream/provision/fabric/README.md)
and [`../docs/ontology.md`](../docs/ontology.md).

> **The graph refresh is the gotcha.** An ontology's backing graph starts **empty**; until
> it is refreshed, the Data Agent's ontology questions **hang ~5 min and fail**. If that
> happens, re-run `refresh-ontology-graph.py` (or in the portal: the `…_graph` item →
> **… → Schedule → Refresh now**), then re-run `create_fabric_data_agent.py`.

### 2. Seed the four IQ connections

Register the four Microsoft IQ connections in your Foundry IQ project — **Foundry IQ**
(`caldova-supply-kb`, Azure AI Search KB), **Fabric IQ** (`caldova-supply-dataagent`),
**Work IQ** (`WorkIQ`), and **Web IQ** (`WebIQ`). This also seeds the Caldova document
corpus into the knowledge base. See [`../infra/README.md`](../infra/README.md).

### 3. Deploy the Foundry Hosted Agent (demos 1–4)

From [`../src/foundry-hosted-agent/`](../src/foundry-hosted-agent/):

```powershell
# Create the one toolbox (all four IQs; Fabric + Work IQ via UserEntraToken → per-user OBO)
./infra/scripts/create-toolbox.ps1  # pass your project + Fabric workspace/data-agent ids

# Build the image + deploy the hosted agent
./infra/scripts/deploy.ps1
```

The agent is a single `FoundryToolbox` reference; Microsoft Foundry runs the loop, so each
IQ call shows in the **Traces** tab. Details:
[`../src/foundry-hosted-agent/README.md`](../src/foundry-hosted-agent/README.md).

### 4. Deploy + hire the autopilot (demo 5)

From the repo root: `azd up` provisions the hosting project + builds and creates the
autopilot; then register it in Agent 365, approve the blueprint, and **hire an instance in
Teams**. Full walkthrough (with the admin approval and grant steps):
[`../docs/setup.md`](../docs/setup.md) and [`../instructions/README.md`](../instructions/README.md).

### 5. Seed the demo mailboxes

Two distinct escalation emails make the "reads *my* mailbox vs *its own* mailbox" story land:

- **Your** mailbox (demo 4, Playground, on-behalf-of you): a cold-chain escalation from
  **Priya Nair — SHP-9021 (Brightline Labs)**. Send it to yourself.
- **The agent's** mailbox (demo 5, Teams): a cold-chain escalation from
  **Maria Garcia — SHP-1234 (Alvexa)**.

### 6. Pre-flight checks (T-10 min, before recording)

- All four IQ connections healthy in the Foundry IQ project.
- **Warm up Fabric IQ — both sources**: ask one OTIF question *and* one ontology question
  (e.g. "Which medicinal products contain Caldovexine?") so neither cold-starts on stage.
- Hosted agent reachable in the Playground; autopilot hired and responding in Teams.
- After any redeploy, retire the old agent version so the Playground/Teams roll to `@latest`.



1. **Context is the differentiator** — the four IQs give agents trusted enterprise grounding.
2. **One backbone, many agents** — build one agent grounded in Microsoft IQ, then the next one
   faster on the *same* IQ (no new connectors or RAG).
3. **Enterprise-ready** — permission-aware, traceable, centrally governed via Agent 365.

## Support

Content owners / contacts: **Ayça Baş** (https://github.com/aycabas) and **Pamela Fox** (https://github.com/pamelafox)
