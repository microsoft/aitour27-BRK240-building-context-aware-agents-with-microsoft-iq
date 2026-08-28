# Delivery Resources

Presenter and train-the-trainer materials for **BRK240 — Building context-aware agents with
the Microsoft IQ platform**. The demo follows **Caldova Pharmaceuticals**, a fictional global
pharma company, as its supply-assurance analyst handles a cold-chain escalation — grounding
every decision across the four Microsoft IQs (Web, Foundry, Fabric, and Work IQ).

## Delivery checklist

- Review the session [README](../README.md) and attendee [instructions](../instructions/README.md)
- Review the [demo flows](demos/README.md) (five per-demo run of show + prompts)
- Open the deck (Caldova supply-assurance storyline)
- Set up the environment top to bottom (see [Prepare your environment](#prepare-your-environment) below)
- Validate the environment: both agents deployed, all four IQ connections healthy, Caldova
  corpus seeded (Foundry IQ KB + Fabric IQ), demo mailboxes seeded
- Warm the Fabric Data Agent — both sources — with one query each before going live

## Core materials

| Item | Link | Notes |
|---|---|---|
| Delivery deck | _add link_ | The session delivery slides (Caldova supply-assurance storyline) |
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
  Teams. It is a governed **Agent 365 autopilot with its own identity** — it reports to
  you, is managed in the admin center, and acts on your behalf (including replying from
  its own mailbox).

### Prerequisites

**Accounts and licenses**

- An **Azure subscription** with rights to **create resources and assign roles** — this
  means **Owner**, or **Contributor + User Access Administrator**. Contributor alone is
  not enough, because the setup scripts create role assignments (ACR pull, Cognitive
  Services User, Fabric workspace membership, OAuth2 grants).
- A **Microsoft 365 tenant** with **Agent 365 + Microsoft Copilot** licenses, enrolled in
  the [Frontier preview program](https://adoption.microsoft.com/en-us/copilot/frontier-program/).
  Publishing and approving the autopilot in Agent 365 (demo 5) requires a
  **Global Administrator** in that tenant.

**`azd up` provisions and builds most of it**

Running `azd up` (step 1 below) provisions the Azure resources with Bicep and then runs a
postprovision hook that builds the whole demo:

- **Provisions** (Bicep): the Microsoft Foundry account + project, a Container Registry, an
  **Azure AI Search** service, and (optionally) a **Microsoft Fabric capacity**.
- **Builds** (postprovision hook): the Fabric data (lakehouse, ontology + graph, semantic
  model, report, `SupplierDataAgent`), the four Microsoft IQ connections, the
  `caldova-supply-tools` toolbox + the **Foundry Hosted Agent**, the **autopilot** container
  + version, and seeds the demo emails.

**You still provide**

- The **Azure subscription** and **M365 licenses** above.
- A **Web IQ** private-preview key (`WEB_IQ_API_KEY`) — Web IQ can't be auto-provisioned.
- A **Microsoft Fabric workspace** on the capacity, and its id (`FABRIC_WORKSPACE_ID`) — a
  Fabric *capacity* is provisioned by Bicep, but a *workspace* is created in the Fabric
  portal/REST API (not Bicep), so you create the workspace on the capacity and pass its id.
- The **admin-gated Agent 365 steps** for demo 5 (approve the blueprint, hire in Teams) —
  these require a Global Administrator and can't be fully automated.

**Tools**

- [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) (`azd`)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) (`az`)
- [Python 3.11+](https://www.python.org/downloads/) and [uv](https://docs.astral.sh/uv/)
- [Visual Studio Code](https://code.visualstudio.com/)

Full prerequisites and permissions detail: [`../docs/setup.md`](../docs/setup.md).

### 1. One command — `azd up`

From the repo root, authenticate and run the one command. Provide your Web IQ key and
Fabric workspace so the postprovision hook can seed everything:

```bash
az login
azd auth login

# Inputs the postprovision hook needs (create the Fabric workspace on your capacity first):
azd env set FABRIC_WORKSPACE_ID <your-fabric-workspace-guid>
azd env set WEB_IQ_API_KEY      <your-web-iq-preview-key>

azd up
```

`azd up` provisions the Azure resources (Foundry + Container Registry + Azure AI Search,
and a Fabric capacity if `deployFabricCapacity=true`), then the postprovision hook
([`../infra/hooks/postprovision.ps1`](../infra/hooks/postprovision.ps1)) builds the Fabric
data (with the required ontology **graph refresh**), seeds the four IQ connections, creates
the toolbox + Foundry Hosted Agent, builds the autopilot, and seeds the demo emails.

> **The ontology graph refresh is a known gotcha** — the hook runs it, but if an ontology
> question later **hangs ~5 min and fails**, re-run
> [`../infra/scripts/refresh-ontology-graph.py`](../infra/scripts/refresh-ontology-graph.py)
> (or in the portal: the `…_graph` item → **… → Schedule → Refresh now**), then re-run the
> Data Agent step. See [`../docs/ontology.md`](../docs/ontology.md).

### 2. Finish the autopilot (admin-gated, demo 5)

`azd up` builds the autopilot container + version; the **Agent 365 registration** is a
separate admin step. As a **Global Administrator**: run
[`../infra/a365/publish-autopilot.ps1`](../infra/a365/publish-autopilot.ps1), approve the
blueprint in the admin center, and **hire an instance in Teams**. Full walkthrough:
[`../docs/setup.md`](../docs/setup.md) and [`../instructions/README.md`](../instructions/README.md).

### 3. Seed the demo mailboxes

The hook seeds **your** mailbox automatically; the **agent** mailbox is seeded after the
autopilot is hired. Two distinct escalations make the "reads *my* mailbox vs *its own*
mailbox" story land:

- **Your** mailbox (demo 4, Playground, on-behalf-of you): **Priya Nair — SHP-9021
  (Brightline Labs)**.
- **The agent's** mailbox (demo 5, Teams): **Maria Garcia — SHP-1234 (Alvexa)** — re-run
  [`../infra/hooks/seed-emails.ps1`](../infra/hooks/seed-emails.ps1) `-AgentMailbox <agent-upn>`
  after hiring.

### 4. Pre-flight checks (T-10 min, before recording)

- All four IQ connections healthy in the Foundry project.
- **Warm up Fabric IQ — both sources**: ask one OTIF question *and* one ontology question
  (e.g. "Which medicinal products contain Caldovexine?") so neither cold-starts on stage.
- Hosted agent reachable in the Playground; autopilot hired and responding in Teams.
- After any redeploy, retire the old agent version so the Playground/Teams roll to `@latest`.

## Key messages


1. **Context is the differentiator** — the four IQs give agents trusted enterprise grounding.
2. **One backbone, many agents** — build one agent grounded in Microsoft IQ, then the next one
   faster on the *same* IQ (no new connectors or RAG).
3. **Enterprise-ready** — permission-aware, traceable, centrally governed via Agent 365.

## Support

Content owners / contacts: **Ayça Baş** (https://github.com/aycabas) and **Pamela Fox** (https://github.com/pamelafox)
