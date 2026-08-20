# Data — Caldova supplier corpus

Canonical synthetic data for the **Caldova Supply Autopilot**. The agent grounds in this
data across the four IQs. The scenario is **CMO (contract manufacturer) supplier
assurance**: qualifying suppliers, tracking their performance, and handling a cold-chain
escalation.

> Synthetic, fictional data for demo purposes only. Suppliers, emails, lots, and
> documents are not real.

## `caldova-upstream/` — the official Caldova dataset (source of truth)

Vendored from the official Caldova sample-data repository. This is the reproducible
source for **Fabric IQ** and most of **Foundry IQ**.

- `sample-data/fabric/` — the `SupplierSM` semantic model + `Supplier Performance`
  report definitions (deployed to Fabric by the upstream provision scripts).
- `sample-data/json/` — structured datasets, including `suppliers.json` (the canonical
  18-supplier registry), `supplier-kpi-profiles.json` (the Fabric performance model),
  `medicinal-product-ontology.json` (the ontology entities and relationships), and
  `waypoint-supplier-invoices.json`.
- `sample-data/pdfs/` — 37 documents: RFP + bidder responses, master manufacturing
  agreements, purchase order, GMP inspection, certificates of analysis,
  nonconformance/deviation/yield reports, invoices, and the cold-chain temperature +
  excursion reports.
- `provision/fabric/*.py` — the `uv`-based scripts that build the Fabric stack
  (lakehouse → ontology → semantic model → report → Data Agent).
- `questions.md` — the upstream catalog of sample questions per source, including the
  Data Agent questions that combine the semantic model and the ontology.

### Fabric IQ tables (14 Delta tables)

Loaded into the `CaldovaSupplierAnalytics` lakehouse and exposed through
`SupplierDataAgent`.

**Supplier analytics** (from `suppliers.json` + `supplier-kpi-profiles.json`):

| Table | Grain | Key content |
|:---|:---|:---|
| `DimSupplier` | one row per supplier (18) | identity, service category, location, capacity, MOQ, financial rating |
| `SupplierPerformance` | weekly snapshot per supplier | OTIF %, batch rejection, right-first-time, complaints, utilization, lead time, cost index, tech-transfer %, open regulatory actions |
| `DimLocation` | one row per location | location, state/region, country |
| `DimInspectionResult` | one per inspection code | NAI / VAI / OAI, severity, disqualifying |
| `DimAuditResult` | one per audit result | rank, passing |
| `DimFinancialRating` | one per rating | rank, investment-grade |
| `DimDate` | calendar | date attributes for trends |

**Ontology** (from `medicinal-product-ontology.json`):

| Table | Grain | Key content |
|:---|:---|:---|
| `MedicinalProduct` | one row per product (6) | name, dosage form, strength, route of administration |
| `ActiveSubstance` | one row per substance (7) | preferred name, substance type |
| `Manufacturer` | one row per manufacturer (4) | name, country, approval status |
| `MarketingAuthorization` | one row per authorization (10) | authorization number, market, status, effective date |
| `RegulatoryAgency` | one row per agency (3) | name, abbreviation, country/region |
| `ProductActiveSubstance` | product ↔ substance join (7) | backs the `contains` relationship |
| `ManufacturerActiveSubstance` | manufacturer ↔ substance join (10) | backs the `manufactures` relationship |

**The ontology graph** (`CaldovaMedicinalProductOntology`): `MedicinalProduct -contains->
ActiveSubstance`, `Manufacturer -manufactures-> ActiveSubstance`, `MedicinalProduct
-hasAuthorization-> MarketingAuthorization`, `MarketingAuthorization -issuedBy->
RegulatoryAgency`.

`SupplierDataAgent` is attached to **both** `SupplierSM` and the ontology, and the two
join on `Manufacturer.manufacturerId` ↔ `DimSupplier.SupplierID` — so a single question
can span supplier performance and product dependencies.

**Demo suppliers:** Summit Dose (selected CMO for RFP CALD-201), Aster Ridge, Atlas
Regional, BluePeak Biologics (GMP inspection subject), Meridian API Works, Keystone
Device Assembly, and others.

## `knowledge-base/` — Foundry IQ policies

Hand-authored Caldova policy markdown, uploaded to the Azure AI Search knowledge base
`caldova-supply-kb` as the **policies** knowledge source:

| File | Grounds |
|:---|:---|
| `cold-chain-temperature-excursion-policy.md` | Excursion severity, disposition, replacement eligibility |
| `returns-replacement-and-credit-policy.md` | Return/replacement/credit rules + approval thresholds |
| `good-distribution-practice-sla.md` | OTIF delivery SLAs, chain of custody, escalation triggers |

The other knowledge sources — **procurement**, **quality**, and **cold-chain** — are
built from the `caldova-upstream` PDFs/JSON by `seed-foundryiq-docs.py`.

## How the four IQs are grounded

| IQ | Grounded by | Seeded / built by |
|:---|:---|:---|
| **Fabric IQ** (numbers + graph) | `caldova-upstream` supplier model + `CaldovaMedicinalProductOntology` | `caldova-upstream/provision/fabric/*.py` |
| **Foundry IQ** (documents) | `knowledge-base/*.md` + `caldova-upstream` PDFs/JSON | `seed-foundryiq.py` + `seed-foundryiq-docs.py` |
| **Work IQ** (mailbox) | a seeded escalation email in the agent's mailbox | manual (send to the agent's mailbox) |
| **Web IQ** (real world) | live web | connection reference only |

See [`../infra/README.md`](../infra/README.md) for the one-command (`azd up`) flow and
[`../docs/ontology.md`](../docs/ontology.md) for the ontology.
