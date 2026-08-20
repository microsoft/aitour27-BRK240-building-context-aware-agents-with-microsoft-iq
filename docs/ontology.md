# Fabric IQ ontology — `CaldovaMedicinalProductOntology`

The Fabric IQ **ontology** gives `SupplierDataAgent` a graph layer over Caldova's
medicinal-product data, so it can answer *dependency* questions — what goes into what,
who is approved to make it, and where it's authorized — as a graph rather than as flat
SQL/DAX over a star schema.

```
CaldovaSupplierAnalytics (Delta) → CaldovaMedicinalProductOntology (graph) ─┐
                                 → SupplierSM (semantic model) ─────────────┴→ SupplierDataAgent (NL)
```

The ontology is defined and deployed entirely by the **upstream Caldova dataset** —
`data/caldova-upstream/provision/fabric/create_fabric_ontology.py`. This repo does not
maintain its own ontology script; see [`../data/README.md`](../data/README.md).

## Entities and relationships

Five entity types, bound to Delta tables in the `CaldovaSupplierAnalytics` lakehouse:

| Entity | Bound table | Key | Properties |
|---|---|---|---|
| `MedicinalProduct` | `MedicinalProduct` | `productId` | name, dosageForm, strength, routeOfAdministration |
| `ActiveSubstance` | `ActiveSubstance` | `substanceId` | preferredName, substanceType |
| `Manufacturer` | `Manufacturer` | `manufacturerId` | name, country, approvalStatus |
| `MarketingAuthorization` | `MarketingAuthorization` | `authorizationId` | authorizationNumber, market, status, effectiveDate |
| `RegulatoryAgency` | `RegulatoryAgency` | `agencyId` | name, abbreviation, countryOrRegion |

Four relationships, contextualized through join tables:

| Relationship | From → To | Context table |
|---|---|---|
| `contains` | MedicinalProduct → ActiveSubstance | `ProductActiveSubstance` |
| `manufactures` | Manufacturer → ActiveSubstance | `ManufacturerActiveSubstance` |
| `hasAuthorization` | MedicinalProduct → MarketingAuthorization | `MarketingAuthorization` |
| `issuedBy` | MarketingAuthorization → RegulatoryAgency | `MarketingAuthorization` |

## Why it earns its place

`SupplierSM` and the ontology are **different data**, not two views of the same thing:

- **`SupplierSM`** knows how suppliers *perform* — OTIF, batch rejection, capacity,
  cost index, open regulatory actions, week over week.
- **The ontology** knows what *depends on* what — which substances go into which
  products, who is approved to make them, and which markets they're authorized in.

`SupplierDataAgent` is attached to both and told to join
`Manufacturer.manufacturerId` (ontology) to `DimSupplier.SupplierID` (semantic model),
so one question can span performance *and* dependency:

> Which approved API manufacturers have available capacity and no open regulatory
> actions, and which medicinal products depend on their active substances?

The full catalog of questions per source is in
[`../data/caldova-upstream/questions.md`](../data/caldova-upstream/questions.md).

## How it's created

The ontology is provisioned as part of the normal seeding flow — no manual step:

```powershell
./infra/scripts/seed.ps1          # runs the upstream Fabric scripts + the graph build
```

Order matters. `create_fabric_ontology.py` must run **after** the lakehouse (it waits
for its seven source tables to appear in the Fabric catalog) and **before**
`create_fabric_data_agent.py` (which reads `FABRIC_ONTOLOGY_ID` from the upstream
`.env`). The graph build runs directly after the ontology is created.

```powershell
cd data/caldova-upstream
uv run python provision/fabric/create_fabric_ontology.py --validate-only   # offline check
uv run python provision/fabric/create_fabric_ontology.py                   # deploy
```

Authentication uses `AzureDeveloperCliCredential`, so `azd auth login` must be signed in
to the Fabric tenant — the scripts do **not** use the `az` identity.

The script writes these back to `data/caldova-upstream/.env`:

```dotenv
FABRIC_ONTOLOGY_ID=...
FABRIC_ONTOLOGY_UI_URL=...
FABRIC_ONTOLOGY_MCP_URL=...
```

> **No portal step — but the graph must be built.** Creating the ontology materializes a
> backing graph model that starts **empty**. Until it is refreshed, `SupplierDataAgent`
> answers ontology questions with *"the graph model required to answer this query is
> currently unavailable."* The upstream provisioning does not trigger that refresh, so
> this repo runs [`../infra/scripts/refresh-ontology-graph.py`](../infra/scripts/refresh-ontology-graph.py)
> immediately after. It is a normal Fabric job (`POST .../graphModels/{id}/jobs/refreshGraph/instances`)
> and takes a few minutes — no Fabric portal **Publish** is required.
>
> Re-run it any time the lakehouse ontology tables change; it is idempotent.

```powershell
# standalone (from the repo root)
cd data/caldova-upstream
uv run python ../../infra/scripts/refresh-ontology-graph.py
```

## Verify

In the Fabric portal, open **`SupplierDataAgent` → data sources**. Expect exactly
**two**: `SupplierSM` and `CaldovaMedicinalProductOntology`. If an older ontology is
still listed, remove it — the provision script adds datasources but never removes
stale ones, and an extra source competes during source selection.

Then test in the Data Agent chat:

- *Which active substances have only one approved manufacturer?* → ontology (GQL)
- *Rank all suppliers by latest OTIF and flag any with open regulatory actions.* → `SupplierSM` (DAX)

Each answer's **steps** panel shows the selected source and the generated query — that's
how you confirm the ontology is actually being *used*, not merely attached.
