# Demo 2 — Business data with Fabric IQ

> Recording: _add link_ · Duration target: ~4–5 min

**Goal.** Show that the agent can reason over **live enterprise business data** —
Caldova's supplier/CMO performance *and* its medicinal-product relationships — through
**Fabric IQ**, and show how little it took to wire it into the agent. We start in
**Microsoft Fabric**, walk the data layer (lakehouse → semantic model → ontology →
Data Agent), then show the agent's code and instructions that connect to it.

**Why it matters.** No exported spreadsheets, no ETL into the agent. The agent asks a
**Fabric Data Agent** in natural language and gets governed answers over the real model.

## Setup

> New environment? Do the [setup](../../docs/setup.md) first (prerequisites + deploy + seed).

- Fabric workspace **Caldova Supply Chain** with the Caldova stack:
  - `CaldovaSupplierAnalytics` (lakehouse, 14 Delta tables: 7 supplier analytics tables —
    DimSupplier, SupplierPerformance, DimLocation, DimInspectionResult, DimAuditResult,
    DimFinancialRating, DimDate — plus 7 ontology tables: MedicinalProduct,
    ActiveSubstance, Manufacturer, MarketingAuthorization, RegulatoryAgency,
    ProductActiveSubstance, ManufacturerActiveSubstance)
  - `SupplierSM` (semantic model)
  - `CaldovaMedicinalProductOntology` (the Fabric IQ ontology)
  - `SupplierDataAgent` (the natural-language Data Agent, attached to **both**
    `SupplierSM` and the ontology)
- The agent reaches it through the Foundry connection `caldova-supply-dataagent`
  (`fabric_dataagent_preview`), which binds to the published `SupplierDataAgent`.

> **Warm-up (important).** The first Data Agent question after provisioning or a graph
> refresh cold-starts and can fail outright — a first ask has returned an HTTP 500 and
> *"the graph model required to answer this query is currently unavailable"*, then
> succeeded on retry. Ask **one question against each source** (one OTIF question and
> one ontology question) ~1–2 minutes before the demo.

## Instructions

### Part A — the workspace and data model

1. Open the **Fabric** workspace **Caldova Supply Chain**. Show it's a clean, single
   stack (lakehouse, semantic model, ontology, Data Agent, report).
2. Open **`SupplierSM`** (semantic model) and show the tables and relationships —
   suppliers linked to locations, inspection results, audit results, financial ratings.
3. Open **`CaldovaMedicinalProductOntology`** and show the graph: **Medicinal Product**
   `contains` **Active Substance**, **Manufacturer** `manufactures` **Active Substance**,
   **Medicinal Product** `hasAuthorization` **Marketing Authorization**, and
   **Marketing Authorization** `issuedBy` **Regulatory Agency**. This is the
   relationship layer — the semantic model knows *how suppliers perform*, the ontology
   knows *what depends on what*.

### Part B — the Data Agent

4. Open **`SupplierDataAgent`**. Show its **two data sources** — `SupplierSM` and
   `CaldovaMedicinalProductOntology` — and their **AI instructions**: the semantic model
   is told to use DAX for current status and movement; the ontology is told to generate
   **GQL**, and to join `Manufacturer.manufacturerId` to `DimSupplier.SupplierID` when a
   question needs both.
5. In the Data Agent's own chat, ask (warm it if you haven't) — **semantic model**:

   > Rank all suppliers by latest OTIF and flag any with open regulatory actions.

6. Show the ranked list over the real model. Then an **ontology** question:

   > Which active substances have only one approved manufacturer?

7. Finally, the one that needs **both sources** — the payoff of this demo:

   > Which approved API manufacturers have available capacity and no open regulatory
   > actions, and which medicinal products depend on their active substances?

   Capacity and regulatory actions come from `SupplierSM`; manufacturer → substance →
   product comes from the ontology. Point out that one question spanned both.

### Part C — how the agent wires to it (code)

8. In **VS Code**, open `src/agent/agent.py` and show `_load_iq_tools` attaching the
   Fabric IQ tool as `fabric_dataagent_preview` via the `FABRIC_CONNECTION_ID`
   connection — "one tool reference; the Data Agent does the querying."
9. Open `src/agent/instructions.md` and show the **routing boundary**: numbers,
   rankings, OTIF, regulatory/audit/financial status → **Fabric IQ**; documents →
   Foundry IQ. Highlight how specific the instructions are — this is what keeps the
   IQs from overlapping.
10. (Optional) Chat with the agent (Foundry Toolkit) to show the same Fabric answer
    coming through the full agent, not just the Data Agent:

    > Rank suppliers by OTIF and flag any with open regulatory actions.

## Questions used

| Ask | Source | Notes |
|---|---|---|
| Rank all suppliers by latest OTIF and flag any with open regulatory actions. | `SupplierSM` (DAX) | Ranked list over the live model |
| Which active substances have only one approved manufacturer? | Ontology (GQL) | Graph traversal the semantic model can't do |
| Which approved API manufacturers have available capacity and no open regulatory actions, and which medicinal products depend on their active substances? | **Both** | Joins on `Manufacturer.manufacturerId` ↔ `DimSupplier.SupplierID` |
| (optional) Which medicinal products contain a given active substance? | Ontology (GQL) | Simple one-hop traversal |

> Keep each question single-intent, except the deliberate cross-source one above —
> that one is *supposed* to span both sources, and it's the point of the demo. If the
> Data Agent errors on it, fall back to asking the two halves separately.

## Verified answers (from live runs)

Actual responses from `SupplierDataAgent` after provisioning — use them to sanity-check
the environment before recording. The Data Agent's natural-language layer rephrases
between runs, so treat these as *shape and substance*, not exact strings.

- *Which active substances have only one approved manufacturer?* → single-source
  substances including **Neravalate** and **Respivanol** (NovaCura API Sciences),
  **Glycoride** and **Immunarin** (Rheinwerk Pharma Ingredients), and **Dermalunide**
  (Meridian API Works). Caldovexine is the one dual-sourced substance, so it may or may
  not appear depending on how the run interprets "only one".
- *Rank all suppliers by latest OTIF…* → 18 suppliers, **Summit Dose 98.5%** top,
  **BluePeak 88.4%** bottom, none with open regulatory actions.
- *Which approved API manufacturers have available capacity…* → **Meridian API Works**
  (310k/mo) → Caldovexine → *Caldovex*; **NovaCura API Sciences** (280k/mo) →
  Neravalate → *Neraval*, Respivanol → *Respivane*; **Rheinwerk Pharma Ingredients**
  (240k/mo) → Glycoride → *Glycora Duo*, Immunarin → *Immunara*; **Pacifica Active
  Ingredients** (360k/mo, no substances listed).

> If an ontology question instead returns *"the graph model required to answer this
> query is currently unavailable"*, the graph needs rebuilding — run
> `uv run python ../../infra/scripts/refresh-ontology-graph.py` from
> `data/caldova-upstream`. See [`../../docs/ontology.md`](../../docs/ontology.md).

## Expected result

- The Data Agent ranks suppliers over the semantic model, traverses the ontology graph,
  and answers a question that needs both.
- The code shows a single tool reference + tight instructions — not custom SQL.

## Talk track

> "This is Caldova's live business data in Fabric — a lakehouse, a semantic model, an
> ontology, and a Data Agent that speaks natural language over all of it. The semantic
> model knows how suppliers are performing. The ontology knows what depends on what —
> which substances go into which products, who's approved to make them, and where
> they're authorized. Ask a question that needs both, and it joins them. The agent
> doesn't export anything; it asks Fabric IQ and gets governed answers. In code, it's
> one tool reference and a few lines of routing — numbers go to Fabric, documents go
> to Foundry."

## Transcript

_After recording, paste the final timed transcript here (also lives in the deck speaker notes)._
