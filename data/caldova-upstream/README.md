# Caldova sample data

Reusable fictional pharmaceutical procurement, supplier, quality, logistics,
and operations data for demos, prototypes, and retrieval experiments.

See [sample questions](questions.md) for prompts spanning indexed documents,
Fabric analytics, the medicinal-product ontology, and federated work context.

The [sample-data](sample-data) contains data you can copy into your repository. It contains:

* [pdfs](sample-data/pdfs): 37 finished documents in one flat directory
* [json](sample-data/json): 10 structured scenario and analytics datasets
* [fabric](sample-data/fabric): the supplier semantic model and report definitions

If you need to create Fabric objects or generate new data, see workflow instructions.

## Contents

- [PDF documents](#pdf-documents)
- [JSON datasets](#json-datasets)
- [Fabric IQ semantic models](#fabric-iq-semantic-models)
- [Fabric IQ ontology](#fabric-iq-ontology)
- [Sample questions](questions.md)
- [Optional workflows](#optional-workflows)

## PDF documents

The 37 finished PDFs are stored together in [sample-data/pdfs](sample-data/pdfs).

### Supplier invoices

| PDF | Document |
| --- | --- |
| [INV-SUP-001-2026-10.pdf](sample-data/pdfs/INV-SUP-001-2026-10.pdf) | Aster Ridge Biomanufacturing invoice. |
| [INV-SUP-002-2026-10.pdf](sample-data/pdfs/INV-SUP-002-2026-10.pdf) | Northstar Fill Finish invoice. |
| [INV-SUP-003-2026-10.pdf](sample-data/pdfs/INV-SUP-003-2026-10.pdf) | HelioPack Pharma Services invoice. |
| [INV-SUP-004-2026-10.pdf](sample-data/pdfs/INV-SUP-004-2026-10.pdf) | Meridian API Works invoice. |
| [INV-SUP-005-2026-10.pdf](sample-data/pdfs/INV-SUP-005-2026-10.pdf) | Crescent GMP Labs invoice. |
| [INV-SUP-006-2026-10.pdf](sample-data/pdfs/INV-SUP-006-2026-10.pdf) | Summit Dose Manufacturing invoice. |
| [INV-SUP-007-2026-10.pdf](sample-data/pdfs/INV-SUP-007-2026-10.pdf) | Orchid Clinical Supply invoice. |
| [INV-SUP-008-2026-10.pdf](sample-data/pdfs/INV-SUP-008-2026-10.pdf) | Valence Cold Chain Logistics invoice. |
| [INV-SUP-009-2026-Q4.pdf](sample-data/pdfs/INV-SUP-009-2026-Q4.pdf) | BluePeak Biologics invoice. |
| [INV-SUP-010-2026-10.pdf](sample-data/pdfs/INV-SUP-010-2026-10.pdf) | Keystone Device Assembly invoice. |
| [INV-SUP-011-2026-10.pdf](sample-data/pdfs/INV-SUP-011-2026-10.pdf) | LumaSterile Services invoice. |
| [INV-SUP-012-2026-10.pdf](sample-data/pdfs/INV-SUP-012-2026-10.pdf) | Pioneer Process Development invoice. |
| [INV-SUP-013-2026-10.pdf](sample-data/pdfs/INV-SUP-013-2026-10.pdf) | Evergreen Excipients invoice. |
| [INV-SUP-014-2026-10.pdf](sample-data/pdfs/INV-SUP-014-2026-10.pdf) | Atlas Regional Manufacturing invoice. |
| [INV-SUP-015-2026-10.pdf](sample-data/pdfs/INV-SUP-015-2026-10.pdf) | Signal Ridge Regulatory Services invoice. |

### Temperature reports

| PDF | Document |
| --- | --- |
| [TL-VCL-1026.pdf](sample-data/pdfs/TL-VCL-1026.pdf) | Temperature logger report for shipment `SHIP-VC-1026-BOS-FRA`. |
| [EXC-VC-1026-04.pdf](sample-data/pdfs/EXC-VC-1026-04.pdf) | Temperature excursion investigation for the same shipment. |

### Operational reports

| PDF | Document |
| --- | --- |
| [YLD-MAW-1026.pdf](sample-data/pdfs/YLD-MAW-1026.pdf) | Meridian `AUR-API-7` lot yield worksheet. |
| [YTA-MAW-1026-04.pdf](sample-data/pdfs/YTA-MAW-1026-04.pdf) | Meridian yield true-up assessment. |
| [FIR-KDA-1026.pdf](sample-data/pdfs/FIR-KDA-1026.pdf) | Keystone auto-injector final inspection report. |
| [NCR-KDA-1026-07.pdf](sample-data/pdfs/NCR-KDA-1026-07.pdf) | Keystone nonconformance and scrap disposition. |
| [UTL-BPB-1026.pdf](sample-data/pdfs/UTL-BPB-1026.pdf) | BluePeak bioreactor utilization and run log. |
| [DEV-BPB-1026.pdf](sample-data/pdfs/DEV-BPB-1026.pdf) | BluePeak contamination deviation investigation. |

### Policy, certificate, and inspection

| PDF | Document |
| --- | --- |
| [CAL-POL-PUR-001.pdf](sample-data/pdfs/CAL-POL-PUR-001.pdf) | Caldova global purchasing policy. |
| [COA-MD-1026-A.pdf](sample-data/pdfs/COA-MD-1026-A.pdf) | Spanish certificate of analysis for Meridian lot `LOT-MD-1026-A`. |
| [GMP-INS-BPB-2027-01.pdf](sample-data/pdfs/GMP-INS-BPB-2027-01.pdf) | Caldova supplier-quality inspection report for BluePeak Biologics. |

### Procurement chain

| PDF | Document |
| --- | --- |
| [RFP-CAL-OSD-2026-01.pdf](sample-data/pdfs/RFP-CAL-OSD-2026-01.pdf) | Caldova requirements, mandatory gates, award weights, schedule, and bid forms. |
| [RSP-AST-2026-01.pdf](sample-data/pdfs/RSP-AST-2026-01.pdf) | Aster Ridge response. |
| [RSP-SUM-2026-01.pdf](sample-data/pdfs/RSP-SUM-2026-01.pdf) | Selected Summit Dose response. |
| [RSP-ATL-2026-01.pdf](sample-data/pdfs/RSP-ATL-2026-01.pdf) | Atlas Regional response with a firm-capacity exception. |
| [MSA-CAL-AST-2024-011.pdf](sample-data/pdfs/MSA-CAL-AST-2024-011.pdf) | Aster Ridge framework manufacturing agreement. |
| [MSA-CAL-SUM-2024-017.pdf](sample-data/pdfs/MSA-CAL-SUM-2024-017.pdf) | Summit Dose framework manufacturing agreement. |
| [MSA-CAL-ATL-2025-004.pdf](sample-data/pdfs/MSA-CAL-ATL-2025-004.pdf) | Atlas Regional framework manufacturing agreement. |
| [AMD-MSA-SUM-2026-01.pdf](sample-data/pdfs/AMD-MSA-SUM-2026-01.pdf) | Summit Dose award amendment for `CALD-201`. |
| [PO-CAL-SUM-2026-1108.pdf](sample-data/pdfs/PO-CAL-SUM-2026-1108.pdf) | Initial Summit Dose order for technology transfer and two batches. |

### Complex diagrams

| PDF | Document |
| --- | --- |
| [CAL-MAP-SUP-001.pdf](sample-data/pdfs/CAL-MAP-SUP-001.pdf) | Global supplier footprint and procurement-bidder map. |
| [CAL-MAP-EVD-001.pdf](sample-data/pdfs/CAL-MAP-EVD-001.pdf) | `CALD-201` procurement and evidence topology. |

## JSON datasets

The structured datasets are stored in [sample-data/json](sample-data/json).

| JSON | Contents |
| --- | --- |
| [suppliers.json](sample-data/json/suppliers.json) | Canonical identities, service categories, and locations for 18 suppliers; suppliers do not need to have invoices. |
| [waypoint-supplier-invoices.json](sample-data/json/waypoint-supplier-invoices.json) | Invoices, line items, billing profiles, and document metadata for 15 suppliers. |
| [valence-excursion.json](sample-data/json/valence-excursion.json) | Temperature readings, excursion details, inventory, assessment, and shipment references. |
| [supplier-evidence.json](sample-data/json/supplier-evidence.json) | Operational evidence and assessment packets for Meridian, Keystone, and BluePeak. |
| [caldova-purchasing-policy.json](sample-data/json/caldova-purchasing-policy.json) | Purchasing-policy structure, controls, roles, thresholds, and scorecard. |
| [COA-MD-1026-A.json](sample-data/json/COA-MD-1026-A.json) | Structured Spanish quality-certificate data. |
| [GMP-INS-BPB-2027-01.json](sample-data/json/GMP-INS-BPB-2027-01.json) | Structured GMP inspection, findings, attachments, and CAPA data. |
| [procurement-chain.json](sample-data/json/procurement-chain.json) | RFP, bidder responses, agreements, amendment, and purchase-order data. |
| [supplier-kpi-profiles.json](sample-data/json/supplier-kpi-profiles.json) | Synthetic supplier KPI profiles used by the Fabric analytics model. |
| [medicinal-product-ontology.json](sample-data/json/medicinal-product-ontology.json) | Medicinal products, active substances, regulatory agencies, marketing authorizations, and ontology relationships. |

## Fabric IQ semantic models

[sample-data/fabric](sample-data/fabric) contains the `SupplierSM` semantic model
and `Supplier Performance` report definitions. See the
[Fabric provisioning guide](provision/fabric/README.md) to deploy them.

The semantic models include these tables:

| Table | Grain and purpose | Key content |
| --- | --- | --- |
| [SupplierPerformance](sample-data/fabric/Supply%20Chain%20Operations/SupplierSM%20%28SemanticModel%29/definition/tables/SupplierPerformance.tmdl) | One weekly snapshot per supplier. | OTIF, rejection rate, right-first-time rate, complaints, regulatory and audit status, utilization, lead time, cost, technology-transfer performance, and trend measures. |
| [DimSupplier](sample-data/fabric/Supply%20Chain%20Operations/SupplierSM%20%28SemanticModel%29/definition/tables/DimSupplier.tmdl) | One row per canonical supplier. | Supplier identity, service category, location, experience, capacity, minimum order quantity, inspection count, and financial rating. |
| [DimDate](sample-data/fabric/Supply%20Chain%20Operations/SupplierSM%20%28SemanticModel%29/definition/tables/DimDate.tmdl) | One row per calendar date in the supplier-history window. | Date, year, quarter, month, week, day, and weekend attributes. |
| [DimLocation](sample-data/fabric/Supply%20Chain%20Operations/SupplierSM%20%28SemanticModel%29/definition/tables/DimLocation.tmdl) | One row per supplier location. | Location, state or region, and country. |
| [DimInspectionResult](sample-data/fabric/Supply%20Chain%20Operations/SupplierSM%20%28SemanticModel%29/definition/tables/DimInspectionResult.tmdl) | One row per regulatory inspection result code. | Result name, description, severity, and disqualifying status. |
| [DimAuditResult](sample-data/fabric/Supply%20Chain%20Operations/SupplierSM%20%28SemanticModel%29/definition/tables/DimAuditResult.tmdl) | One row per internal audit result. | Result rank and passing status. |
| [DimFinancialRating](sample-data/fabric/Supply%20Chain%20Operations/SupplierSM%20%28SemanticModel%29/definition/tables/DimFinancialRating.tmdl) | One row per financial stability rating. | Rating rank and investment-grade status. |

## Fabric IQ ontology

The `CaldovaMedicinalProductOntology` models five entity types:

- `MedicinalProduct`
- `ActiveSubstance`
- `Manufacturer`
- `MarketingAuthorization`
- `RegulatoryAgency`

It connects them through `contains`, `manufactures`, `hasAuthorization`, and
`issuedBy` relationships. The ontology is bound to seven dedicated Delta tables in
the `CaldovaSupplierAnalytics` lakehouse. See the
[Fabric provisioning guide](provision/fabric/README.md) to validate and deploy it.

## Optional workflows

- [generation](generation) contains the scenario-first templates, assets, HTML
  previews, and scripts used to reproduce the PDFs. Its
  [data guide](generation/README.md) documents provenance and public references.
- [Fabric provisioning](provision/fabric/README.md) contains scripts and setup
  instructions for creating or updating the lakehouse, ontology, semantic model,
  report, and Data Agent using the definitions and JSON under `sample-data/`.

Both workflows use the root [pyproject.toml](pyproject.toml) and `uv.lock`.
