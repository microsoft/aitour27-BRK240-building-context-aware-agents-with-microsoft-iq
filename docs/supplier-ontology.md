# Caldova Supplier Ontology (Fabric IQ) — reproducibility

The Fabric IQ **Ontology** gives the `SupplierDataAgent` a graph layer over the CMO
supplier data, so the agent can answer relationship questions (supplier ↔ location ↔
inspection ↔ audit ↔ financial rating) as a graph, not just flat SQL/semantic-model
queries.

```
CaldovaSupplierAnalytics (Delta) → SupplierSM (semantic model) → CaldovaSupplierOntology (graph) → SupplierDataAgent (NL)
```

**Entities & relationships**

| Entity | Bound table | Key |
|---|---|---|
| Supplier | `DimSupplier` | SupplierID |
| Location | `DimLocation` | LocationID |
| InspectionResult | `DimInspectionResult` | ResultCode (NAI/VAI/OAI) |
| AuditResult | `DimAuditResult` | AuditResult |
| FinancialRating | `DimFinancialRating` | Rating |

Relationships: `Supplier -locatedIn-> Location`, and via `SupplierPerformance`:
`Supplier -hasInspectionResult-> InspectionResult`, `-hasAuditResult-> AuditResult`,
`-hasFinancialRating-> FinancialRating`.

## How to create it

> ⚠️ Fabric IQ Ontology is a **preview** feature. The script creates the ontology
> *structure* (entities, relationships, bindings) via REST, but the graph **build**
> that makes it query-ready (the ontology → graph compile) is **not** exposed in the
> public Fabric REST API yet — it must be done once in the Fabric portal via
> **Publish**. This is a one-time presenter step; all attendees then share the same
> `SupplierDataAgent`.

### Option A — Portal (most reliable)

1. Fabric workspace → open **`SupplierSM`** → ribbon **Generate Ontology** → name it
   (letters/numbers/underscore only) → **Create**.
2. Open the new ontology → **Publish** (compiles + loads the graph → query-ready).
3. Open **`SupplierDataAgent`** → **Add data source** → select the ontology.

### Option B — Script the structure, then publish in the portal

1. `python infra/scripts/create-supplier-ontology.py`
   (reads `FABRIC_WORKSPACE_ID`, `FABRIC_LAKEHOUSE_ID`, `ONTOLOGY_NAME`; defaults
   target the "Caldova Supply Chain" workspace + `CaldovaSupplierAnalytics` lakehouse).
   This creates `CaldovaSupplierOntology` with the entities, relationships, and
   bindings, matching the portal shape.
2. In the portal: open the ontology → **Publish**, then add it to `SupplierDataAgent`
   (Option A steps 2–3).

> The graph data-load job **is** scriptable
> (`POST /workspaces/{ws}/graphModels/{graph}/jobs/refreshGraph/instances`), but it
> only *refreshes* an already-compiled graph — it returns `GraphNotRefreshable` until
> the ontology has been Published once. Track the preview API for a scriptable compile.

## Why it's optional for the demo

The `SupplierSM` semantic model already carries the supplier ↔ location ↔ inspection ↔
audit ↔ financial relationships, so the `SupplierDataAgent` answers region/grouping
questions ("which suppliers share a region?") **without** the ontology. The ontology
makes the graph story explicit and enables richer traversals; publish it for the full
Fabric IQ narrative, but the demo does not break without it.

## Verify

```powershell
# queryReadiness should become "Ready" after Publish
$tok = az account get-access-token --resource https://api.fabric.microsoft.com --query accessToken -o tsv
$ws  = $env:FABRIC_WORKSPACE_ID
$graph = "<ontology graph model id>"
(Invoke-RestMethod "https://api.fabric.microsoft.com/v1/workspaces/$ws/graphModels/$graph" -Headers @{Authorization="Bearer $tok"}).properties.queryReadiness
```

Then test the agent: *"Which suppliers are located in the same region as each other?"*
