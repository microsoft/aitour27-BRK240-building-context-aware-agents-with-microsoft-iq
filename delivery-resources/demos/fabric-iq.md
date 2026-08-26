# Demo 3 — Fabric IQ

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

> **Why both a semantic model AND an ontology? (say this on stage)** They answer two
> different kinds of question over the same Fabric data, and the Data Agent uses whichever
> fits. **`SupplierSM` (semantic model) = the numbers** — metrics and aggregations (OTIF,
> quality, regulatory/audit/financial, rankings); great for *"how much / how many / rank
> by / flag where,"* but it has **no path** to walk multi-step relationships.
> **`CaldovaMedicinalProductOntology` (ontology / graph) = the relationships** — a graph
> of Medicinal Product → Active Substance → Manufacturer → Authorization, for *"what
> depends on what / which connects to which."* The point: **Fabric IQ is numbers *and*
> relationships over your system of record** — one Data Agent spans both. That's *"how
> your business operates,"* not just SQL over tables.

### Part B — the Data Agent

4. Open **`SupplierDataAgent`**. Show its **two data sources** — `SupplierSM` and
   `CaldovaMedicinalProductOntology` — and their **AI instructions**: the semantic model
   is told to use DAX for current status and movement; the ontology is told to generate
   **GQL**, and to join `Manufacturer.manufacturerId` to `DimSupplier.SupplierID` when a
   question needs both.
5. In the Data Agent's own chat, ask (warm it if you haven't) — **semantic model**:

   > Rank all suppliers by latest OTIF and flag any with open regulatory actions.

6. Show the ranked list over the real model. Then a simple, single-hop **ontology** question:

   > Which medicinal products contain Caldovexine?

   One hop through the graph (Medicinal Product `contains` Active Substance) — a
   relationship the semantic model has no path for.
   > **Warm the ontology first** (ask it once ~1–2 min before recording) — the graph can
   > cold-start and time out on the first call. Keep to **single-hop** phrasings on stage.

7. Finally, the one that needs **both sources** — the payoff of this demo:

   > What is Rheinwerk Pharma Ingredients' latest OTIF, and which active substances does
   > it manufacture?

   OTIF comes from `SupplierSM`; the substances come from the ontology (Manufacturer
   `manufactures` Active Substance — a single **forward** hop); they join on
   `Manufacturer.manufacturerId` ↔ `DimSupplier.SupplierID`. One question, both sources.

### Part C — how the agent wires to it (code)

8. In **VS Code**, open `src/foundry-hosted-agent/infra/scripts/create-toolbox.ps1` and show
   the **`fabric-dataagent`** MCP tool in the `caldova-supply-tools` toolbox — bound to the
   `SupplierDataAgent` MCP endpoint via a **`UserEntraToken`** connection, so it resolves as
   the signed-in user. Then open `src/foundry-hosted-agent/src/main.py` — the whole agent is
   a **single `FoundryToolbox`** reference (Microsoft Foundry runs it with auth passthrough).
9. Open `src/foundry-hosted-agent/src/instructions.md` and show the **routing boundary**: numbers,
   rankings, OTIF, regulatory/audit/financial status → **Fabric IQ**; documents →
   Foundry IQ. Highlight how specific the instructions are — this is what keeps the
   IQs from overlapping.
10. Chat with the agent in the **Microsoft Foundry portal Playground** to show the same Fabric
    answer coming through the full agent, then open **Traces** to show
    **`Invoke Agent SupplierDataAgent` → `Execute Tool analyze_semantic_model`**:

    > Rank suppliers by OTIF and flag any with open regulatory actions.

## Questions used

Keep to **single-hop, forward-direction** ontology questions on stage. Recommended set:

| Ask | Source | Notes |
|---|---|---|
| Rank all suppliers by latest OTIF and flag any with open regulatory actions. | `SupplierSM` (DAX) | ✅ rock-solid |
| Which medicinal products contain Caldovexine? | Ontology (GQL) | ✅ **use this** — simplest one-hop |
| What active substances does Rheinwerk Pharma Ingredients manufacture? | Ontology (GQL) | ✅ one-hop, forward direction |
| What is Rheinwerk Pharma Ingredients' latest OTIF, and which active substances does it manufacture? | **Both** | ✅ SM + one-hop ontology, joins on manufacturer ↔ supplier |
| Which medicinal products depend on active substances made by Rheinwerk Pharma Ingredients? | Ontology (GQL) | ⚠️ two-hop — warm up first, or skip on stage |

### Phrasings to avoid on stage

Verified flaky — keep them out of the run of show:

| Ask | Problem |
|---|---|
| *Which active substances have only one approved manufacturer?* | **Returns a wrong answer.** Caldovexine has **two** approved makers (Meridian + Rheinwerk) but is often listed anyway. The correct set is Neravalate, Immunarin, Respivanol, Dermalunide, Glycoride. Rephrasing as *"count how many manufacturers with approval status 'Approved' make each substance, and list those where the count is exactly 1"* fixes the answer but still fails ~1 in 4 with a query syntax error. |
| *Which manufacturers make Glycoride?* | 1/4. The `manufactures` relationship is directed **Manufacturer → ActiveSubstance**; asking substance → manufacturer traverses it backwards and usually returns "no manufacturers found". Ask it in the forward direction instead. |
| *Which API manufacturer has the lowest latest OTIF, and which products depend on it?* | 1/2. Superlative + traversal in one ask; name the manufacturer instead. |
| *Which approved API manufacturers have available capacity and no open regulatory actions, and which medicinal products depend on their active substances?* | Three predicates plus a traversal. Works in isolation but dropped the product mapping when run through the agent in Teams. |

> Rule of thumb: **name the entity, and traverse in the direction the relationship is
> defined.** Superlatives and stacked filters are where it degrades.

## Verified answers (from live runs)

Actual responses from `SupplierDataAgent`, used to sanity-check the environment before
recording. The natural-language layer rephrases between runs, so treat these as *shape
and substance*, not exact strings.

- *Rank all suppliers by latest OTIF…* → 18 suppliers, **Summit Dose 98.5%** top,
  **BluePeak 88.4%** bottom, none with open regulatory actions.
- *Which medicinal products contain Caldovexine?* → **Caldovex** (CALD-201, tablet, 50 mg, oral).
- *Which medicinal products depend on … Rheinwerk Pharma Ingredients?* → **Immunara**
  (Immunarin), **Caldovex** (Caldovexine), **Glycora Duo** (Glycoride).
- *What is Rheinwerk's latest OTIF, and which products depend on it?* → **96.2%** plus
  those same three products.

### Ground truth (for checking answers)

| Manufacturer | Approval | Makes |
|---|---|---|
| Meridian API Works | Approved | Caldovexine, Dermalunide |
| NovaCura API Sciences | Approved | Neravalate, Respivanol |
| Rheinwerk Pharma Ingredients | Approved | Caldovexine, Immunarin, Glycoride |
| Pacifica Active Ingredients | **Conditional** | Respivanol, Dermalunide, Metabex |

Products: Neraval = Neravalate · Caldovex = Caldovexine · Immunara = Immunarin ·
Respivane = Respivanol · Dermalune = Dermalunide · **Glycora Duo = Glycoride + Metabex**.

Note Pacifica is *Conditional*, not Approved — that's what makes Respivanol and
Dermalunide single-**approved**-source, and why Metabex has no approved manufacturer.

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
