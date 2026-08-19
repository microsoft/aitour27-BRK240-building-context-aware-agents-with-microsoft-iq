# Demo 2 — Business data with Fabric IQ

> Recording: _add link_ · Duration target: ~4–5 min

**Goal.** Show that the agent can reason over **live enterprise business data** —
Caldova's supplier/CMO performance — through **Fabric IQ**, and show how little it
took to wire it into the agent. We start in **Microsoft Fabric**, walk the data
layer (lakehouse → semantic model → ontology → Data Agent), then show the agent's
code and instructions that connect to it.

**Why it matters.** No exported spreadsheets, no ETL into the agent. The agent asks a
**Fabric Data Agent** in natural language and gets governed answers over the real model.

## Setup

> New environment? Do the [setup](../../docs/setup.md) first (prerequisites + deploy + seed).

- Fabric workspace **Caldova Supply Chain** with the supplier stack:
  - `CaldovaSupplierAnalytics` (lakehouse, 7 Delta tables: DimSupplier,
    SupplierPerformance, DimLocation, DimInspectionResult, DimAuditResult,
    DimFinancialRating, DimDate)
  - `SupplierSM` (semantic model)
  - `CaldovaSupplierOntology` (graph over the supplier tables)
  - `SupplierDataAgent` (the natural-language Data Agent)
- The agent reaches it through the Foundry connection `caldova-supply-dataagent`
  (`fabric_dataagent_preview`), which binds to the published `SupplierDataAgent`.

> **Warm-up (important).** Ask the Data Agent one OTIF question ~1 minute before the
> demo so the first NL2SQL call on stage isn't a cold start.

## Instructions

### Part A — the workspace and data model

1. Open the **Fabric** workspace **Caldova Supply Chain**. Show it's a clean, single
   stack (lakehouse, semantic model, ontology, Data Agent, report).
2. Open **`SupplierSM`** (semantic model) and show the tables and relationships —
   suppliers linked to locations, inspection results, audit results, financial ratings.
3. Open **`CaldovaSupplierOntology`** and show the graph: **Supplier** connected to
   **Location**, **InspectionResult**, **AuditResult**, **FinancialRating**. This is
   the relationship layer that lets the agent answer "which suppliers share a region."

### Part B — the Data Agent

4. Open **`SupplierDataAgent`**. Show its **data sources** (SupplierSM + ontology) and
   its **AI instructions** — how it's told to treat null manufacturing metrics as
   "not applicable," use latest / four-week-change measures, etc.
5. In the Data Agent's own chat, ask (warm it if you haven't):

   > Rank all suppliers by latest OTIF and flag any with open regulatory actions.

6. Show the ranked list over the real model. Then a relationship question:

   > Which suppliers are located in the same region as each other?

### Part C — how the agent wires to it (code)

7. In **VS Code**, open `src/agent/agent.py` and show `_load_iq_tools` attaching the
   Fabric IQ tool as `fabric_dataagent_preview` via the `FABRIC_CONNECTION_ID`
   connection — "one tool reference; the Data Agent does the querying."
8. Open `src/agent/instructions.md` and show the **routing boundary**: numbers,
   rankings, OTIF, regulatory/audit/financial status → **Fabric IQ**; documents →
   Foundry IQ. Highlight how specific the instructions are — this is what keeps the
   IQs from overlapping.
9. (Optional) Chat with the agent (Foundry Toolkit) to show the same Fabric answer
   coming through the full agent, not just the Data Agent:

   > Rank suppliers by OTIF and flag any with open regulatory actions.

## Questions used

| Ask | Notes |
|---|---|
| Rank all suppliers by latest OTIF and flag any with open regulatory actions. | Ranked list over the live model |
| Which suppliers are located in the same region as each other? | Relationship / grouping |
| (optional) Which suppliers have a VAI or OAI regulatory inspection result? | Regulatory filter |

> Keep each question single-intent. Don't combine "same region **and** an issue" in one
> ask — split it (region first, then the issue), or it can error.

## Expected result

- The Data Agent ranks and groups suppliers over the real Fabric model.
- The code shows a single tool reference + tight instructions — not custom SQL.

## Talk track

> "This is Caldova's live supplier data in Fabric — a lakehouse, a semantic model, an
> ontology, and a Data Agent that speaks natural language over all of it. The agent
> doesn't export anything; it asks Fabric IQ and gets governed answers. In code, it's
> one tool reference and a few lines of routing — numbers go to Fabric, documents go
> to Foundry."

## Transcript

_After recording, paste the final timed transcript here (also lives in the deck speaker notes)._
