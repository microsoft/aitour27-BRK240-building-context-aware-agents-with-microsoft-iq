# Generation data guide

This folder contains the scripts, templates, assets, and HTML previews used to
generate Caldova's fictional sample documents. Finished PDFs and structured JSON
are stored under `sample-data/`.

## Supplier invoices

Invoice facts come from the Waypoint corpus pinned at commit
`045637b6eea72550ce3aad61bfac851356ca824a`. The generator caches its canonical
`supplier-invoices.json` in `sample-data/json/`, renders each record through the
matching supplier template in `generation/invoices/templates/`, and writes a
browser preview to `generation/invoices/html/` and a searchable PDF to
`sample-data/pdfs/`. The 15
supplier templates use different document structures and domain-specific table
labels while sharing print, formatting, and accessibility primitives.

Generate all 15 supplier invoices from the repository root:

```bash
uv run python generation/scripts/generate_invoice.py --all
```

Generate one invoice by ID:

```bash
uv run python generation/scripts/generate_invoice.py INV-SUP-002-2026-10
```

Refresh the cached source from the pinned commit while generating:

```bash
uv run python generation/scripts/generate_invoice.py --all --refresh-source
```

The generator verifies that line amounts sum to the declared invoice total and
that every canonical line ID belongs to its invoice before creating either output.
Reconciliation outcomes remain in the source data and are not rendered into the
supplier-facing documents.

### Generated invoice PDFs

Each PDF below is a direct visual rendering of the named invoice record in the
cached [pinned Waypoint supplier-invoice file](../sample-data/json/waypoint-supplier-invoices.json).
The PDF preserves Waypoint's supplier, invoice, purchase-order, line-item,
reference, quantity, rate, and total facts while omitting expected audit outcomes.

| PDF | Waypoint correspondence |
| --- | --- |
| [INV-SUP-001-2026-10.pdf](../sample-data/pdfs/INV-SUP-001-2026-10.pdf) | Direct rendering of the [Aster Ridge Biomanufacturing invoice](../sample-data/json/waypoint-supplier-invoices.json#L209). |
| [INV-SUP-002-2026-10.pdf](../sample-data/pdfs/INV-SUP-002-2026-10.pdf) | Direct rendering of the [Northstar Fill Finish invoice](../sample-data/json/waypoint-supplier-invoices.json#L268). |
| [INV-SUP-003-2026-10.pdf](../sample-data/pdfs/INV-SUP-003-2026-10.pdf) | Direct rendering of the [HelioPack Pharma Services invoice](../sample-data/json/waypoint-supplier-invoices.json#L327). |
| [INV-SUP-004-2026-10.pdf](../sample-data/pdfs/INV-SUP-004-2026-10.pdf) | Direct rendering of the [Meridian API Works invoice](../sample-data/json/waypoint-supplier-invoices.json#L386). |
| [INV-SUP-005-2026-10.pdf](../sample-data/pdfs/INV-SUP-005-2026-10.pdf) | Direct rendering of the [Crescent GMP Labs invoice](../sample-data/json/waypoint-supplier-invoices.json#L445). |
| [INV-SUP-006-2026-10.pdf](../sample-data/pdfs/INV-SUP-006-2026-10.pdf) | Direct rendering of the [Summit Dose Manufacturing invoice](../sample-data/json/waypoint-supplier-invoices.json#L504). |
| [INV-SUP-007-2026-10.pdf](../sample-data/pdfs/INV-SUP-007-2026-10.pdf) | Direct rendering of the [Orchid Clinical Supply invoice](../sample-data/json/waypoint-supplier-invoices.json#L563). |
| [INV-SUP-008-2026-10.pdf](../sample-data/pdfs/INV-SUP-008-2026-10.pdf) | Direct rendering of the [Valence Cold Chain Logistics invoice](../sample-data/json/waypoint-supplier-invoices.json#L628). |
| [INV-SUP-009-2026-Q4.pdf](../sample-data/pdfs/INV-SUP-009-2026-Q4.pdf) | Direct rendering of the [BluePeak Biologics invoice](../sample-data/json/waypoint-supplier-invoices.json#L687). |
| [INV-SUP-010-2026-10.pdf](../sample-data/pdfs/INV-SUP-010-2026-10.pdf) | Direct rendering of the [Keystone Device Assembly invoice](../sample-data/json/waypoint-supplier-invoices.json#L752). |
| [INV-SUP-011-2026-10.pdf](../sample-data/pdfs/INV-SUP-011-2026-10.pdf) | Direct rendering of the [LumaSterile Services invoice](../sample-data/json/waypoint-supplier-invoices.json#L811). |
| [INV-SUP-012-2026-10.pdf](../sample-data/pdfs/INV-SUP-012-2026-10.pdf) | Direct rendering of the [Pioneer Process Development invoice](../sample-data/json/waypoint-supplier-invoices.json#L870). |
| [INV-SUP-013-2026-10.pdf](../sample-data/pdfs/INV-SUP-013-2026-10.pdf) | Direct rendering of the [Evergreen Excipients invoice](../sample-data/json/waypoint-supplier-invoices.json#L929). |
| [INV-SUP-014-2026-10.pdf](../sample-data/pdfs/INV-SUP-014-2026-10.pdf) | Direct rendering of the [Atlas Regional Manufacturing invoice](../sample-data/json/waypoint-supplier-invoices.json#L988). |
| [INV-SUP-015-2026-10.pdf](../sample-data/pdfs/INV-SUP-015-2026-10.pdf) | Direct rendering of the [Signal Ridge Regulatory Services invoice](../sample-data/json/waypoint-supplier-invoices.json#L1047). |

## Temperature excursion reports

The Valence report pair extends the pinned Waypoint records for shipment
`SHIP-VC-1026-BOS-FRA`. Waypoint supplies the invoice, shipment, proof of
delivery, lane authorization, temperature-log, and investigation identifiers.
The measurements, affected inventory, investigation narrative, and disposition
in `sample-data/json/valence-excursion.json` are fictional but shared
by both generated documents so their facts remain consistent.

The report structure is informed by public examples:

- [University of Iowa investigational product temperature monitoring procedure](https://www.healthcare.uiowa.edu/marcom/uihc/pharmacy/RES-NP002_INVESTIGATIONAL_PRODUCT_TEMPERATURE_MONITORING_ACTIONS.pdf)
- [New York State COVID-19 temperature excursion report](https://www.mssny.org/wp-content/uploads/2022/08/COVID19-Temperature-Excursion-Report_5-26-21.pdf)
- [EIMPRIS temperature excursion report](https://www.medimergent.com/wp-content/uploads/2022/08/EIMPRIS-Temperature-Excursion-Report-11Aug2022.pdf)
- [Sensitech TempTale 4 USB logger report](https://www.bepack.hu/static/media/dry.55b9103650e2f6a30b13.pdf)

Generate the searchable logger and investigation PDFs from the repository root:

```bash
uv run python generation/scripts/generate_temperature_reports.py
```

The generator validates shared measurements and confirms that every Waypoint
identifier used by the reports exists in the pinned Valence invoice. It writes
HTML previews to `temperature-reports/html/` and PDFs to
`sample-data/pdfs/`.

### Generated temperature PDFs

Both documents correspond to the [Waypoint Valence invoice](../sample-data/json/waypoint-supplier-invoices.json#L628),
which names shipment `SHIP-VC-1026-BOS-FRA`, temperature log `TL-VCL-1026`,
investigation `EXC-VC-1026-04`, proof of delivery `VCL-1026-8841`, and lane
authorization `LA-VCL-1026`. Their measurements and conclusions are synthetic
extensions defined in [valence-excursion.json](../sample-data/json/valence-excursion.json).

| PDF | Waypoint correspondence |
| --- | --- |
| [TL-VCL-1026.pdf](../sample-data/pdfs/TL-VCL-1026.pdf) | Realizes Waypoint's named temperature-log evidence as a fictional machine-generated logger report for the same shipment. |
| [EXC-VC-1026-04.pdf](../sample-data/pdfs/EXC-VC-1026-04.pdf) | Realizes Waypoint's investigation reference as a fictional retrospective assessment linked to the same log, shipment, and invoice. |

## Operational evidence and assessments

The operational report corpus adds three evidence-and-assessment pairs to the
pinned Waypoint supplier records. Waypoint supplies the supplier, invoice, line,
lot, build, run, and supporting-document identifiers. All quantities beyond the
invoice facts, process measurements, defect findings, investigation narratives,
people, actions, and dispositions in
`sample-data/json/supplier-evidence.json` are fictional. A single
structured source feeds both documents in each pair so figures, tables, and
conclusions remain consistent.

The public documents below informed field selection and information hierarchy;
the generated reports do not reproduce their branding, wording, or case data:

- [FDA Guidance for Industry #234: Question-Based Review for the Chemistry,
  Manufacturing, and Controls Technical Section of Animal Drug Applications](https://www.fda.gov/media/96718/download)
  informed the Meridian comparison of actual and theoretical yield and material
  reconciliation.
- [21 CFR 211.188: Batch production and control records](https://www.govinfo.gov/content/pkg/CFR-2013-title21-vol4/pdf/CFR-2013-title21-vol4-sec211-188.pdf)
  informed the controlled-record identity, batch quantities, yield checks, and
  review traceability in the Meridian worksheet.
- [FDA Nonconformity Grading System for Regulatory Purposes](https://www.fda.gov/media/152034/download)
  and [APHL Model Practices for Nonconforming Events](https://aphl.org/docs/default-source/technical/QSA-2021-PHL-Model-Practices-QMS11-A.pdf)
  informed Keystone's defect classification, impact, cause, disposition, action,
  approval, and closure sequence.
- [Strategic Biopharmaceutical Production Planning for Batch and Continuous
  Manufacturing](https://discovery.ucl.ac.uk/1505719/1/main.pdf) and
  [Reducing the Costs of Biopharmaceutical Separations and Purification](https://www.mmhimages.com/production/BP_Purolite_eBook_2021.pdf)
  informed BluePeak's run-level capacity table and included, excess, and unused
  capacity figure.
- [Deviation Handling and Quality Risk Management](https://dcvmn.org/wp-content/uploads/2016/03/who_guidance_deviation_and_risk_mgt_2013.pdf)
  and [FDA Investigating Out-of-Specification Test Results for Pharmaceutical
  Production](https://www.fda.gov/media/158416/download) informed the BluePeak
  event, containment, evidence, root-cause, impact, CAPA, and final-disposition
  flow.

Generate all six searchable PDFs from the repository root:

```bash
uv run python generation/scripts/generate_operational_reports.py
```

The generator validates the arithmetic within each packet, confirms every
canonical identifier against the pinned invoice corpus, and checks the linked
invoice-line amount. It writes HTML previews to `operational-reports/html/` and
PDFs to `sample-data/pdfs/`. All measurements, findings, and dispositions
beyond the linked Waypoint facts come from
[supplier-evidence.json](../sample-data/json/supplier-evidence.json).

### Generated operational PDFs

| PDF | Waypoint correspondence |
| --- | --- |
| [YLD-MAW-1026.pdf](../sample-data/pdfs/YLD-MAW-1026.pdf) | Realizes the yield worksheet named by the [Waypoint Meridian invoice](../sample-data/json/waypoint-supplier-invoices.json#L386), using its `LOT-MD-1026-A`, `MAW-API-1026`, and related references with synthetic process measurements. |
| [YTA-MAW-1026-04.pdf](../sample-data/pdfs/YTA-MAW-1026-04.pdf) | Fictional assessment of Waypoint line `INV-SUP-004-2026-10-L004`; it explains why the canonical `$125,600` forecast-based yield adjustment is rejected. |
| [FIR-KDA-1026.pdf](../sample-data/pdfs/FIR-KDA-1026.pdf) | Realizes the final inspection report named by the [Waypoint Keystone invoice](../sample-data/json/waypoint-supplier-invoices.json#L752), preserving its build, inspection, lot, and ECO references with synthetic defect data. |
| [NCR-KDA-1026-07.pdf](../sample-data/pdfs/NCR-KDA-1026-07.pdf) | Fictional nonconformance assessment of Waypoint line `INV-SUP-010-2026-10-L004`; it connects the canonical `$86,450` excess-scrap charge to the generated inspection evidence. |
| [UTL-BPB-1026.pdf](../sample-data/pdfs/UTL-BPB-1026.pdf) | Realizes the utilization log named by the [Waypoint BluePeak invoice](../sample-data/json/waypoint-supplier-invoices.json#L687), preserving the canonical 12,000 included hours, 4,800 excess hours, three runs, and related IDs. |
| [DEV-BPB-1026.pdf](../sample-data/pdfs/DEV-BPB-1026.pdf) | Realizes Waypoint's deviation cost packet and supplier-caused contamination reference for line `INV-SUP-009-2026-Q4-L004`, with a fictional investigation supporting rejection of the canonical `$111,000` fee. |

## Purchasing policy

The Caldova purchasing policy is a fictional global company policy covering
decision principles, approval thresholds, supplier qualification, weighted
evaluation, lifecycle monitoring, ethics, responsible sourcing, and exception
controls. Its searchable 14-page landscape layout uses the Caldova logo and
three original images generated for this demonstration with MAI-Image-2.5.

The policy's visual structure and governance coverage are informed by the
[PharmaMar Group purchasing policy](https://pharmamar.com/wp-content/uploads/2024/03/PHARMAMAR_PURCHASING_POLICY_v2.pdf),
its operational supplier-lifecycle controls by the
[Cipla responsible sourcing policy](https://www.cipla.com/sites/default/files/2024-08/Responsible-Sourcing-Policy.pdf),
and its medicine-specific quality controls by the
[WHO quality assurance policy](https://www.who.int/publications-detail-redirect/9789240023789).
The generated document does not reproduce their branding, wording, photography,
or case data.

Generate the HTML preview and PDF from the repository root:

```bash
uv run python generation/scripts/generate_purchasing_policy.py
```

The generator validates policy dates, approval thresholds, required sections,
and the 100-point supplier scorecard before writing the outputs.

### Generated purchasing policy PDF

- [CAL-POL-PUR-001.pdf](../sample-data/pdfs/CAL-POL-PUR-001.pdf) — Caldova
  Pharmaceuticals purchasing policy, version 1.0, effective 01 September 2026.

## Spanish quality certificate

The Meridian certificate of analysis is a fictional Spanish-language laboratory
record for the existing `AUR-API-7` lot. It is issued by a synthetic Spanish
manufacturing and quality-control affiliate while Meridian's Singapore address
remains the commercial address shown on the English invoice. This creates an
intentional cross-language retrieval path through shared document, lot, material,
invoice, purchase-order, and yield-workbook identifiers.

Its fields and analytical table are informed by the
[WHO model certificate of analysis](https://www.who.int/publications/m/item/trs1010-annex4).
The [EMA information note on electronic certificates](https://www.ema.europa.eu/en/documents/regulatory-procedural-guideline/information-note-format-and-validity-features-electronic-certificates-medicines-issued-european-medicines-agency_en.pdf)
supports Spanish as an established certificate language but is not used as a
visual, signature, seal, or legal-status model.

Generate the searchable three-page PDF from the repository root:

```bash
uv run python generation/scripts/generate_quality_certificate.py
```

The generator validates chronology, analytical completeness, disposition,
released quantity, and all shared references against the pinned Waypoint invoice.

### Generated quality certificate PDF

- [COA-MD-1026-A.pdf](../sample-data/pdfs/COA-MD-1026-A.pdf) — Spanish-only
  certificate for `LOT-MD-1026-A`; corresponds to the
  [Meridian invoice](../sample-data/json/waypoint-supplier-invoices.json#L386) and
  [yield evidence](../sample-data/json/supplier-evidence.json#L8).

## Scanned GMP inspection report

The fictional Caldova supplier-quality inspection of BluePeak Biologics follows
the three-part organization and deficiency taxonomy described by the
[WHO guidance on GMP inspection reports](https://www.who.int/publications/m/item/guidance-on-good-manufacturing-practices-inspection-report).
It is an internal, for-cause supplier inspection rather than a regulatory report
or certification.

The report extends the existing BluePeak contamination scenario. Shared
identifiers connect it to invoice `INV-SUP-009-2026-Q4`, line
`INV-SUP-009-2026-Q4-L004`, run `BP-1026-03`, deviation
`DEV-BP-1026-SUPPLIER`, and assessment `DEV-BPB-1026`. All site details,
inspection observations, deficiencies, CAPA commitments, and inspector names
are fictional.

Its attachments include:

- A facility, control, and contamination-risk map linking campaign runs,
  bioreactor suites `BR-04` and `BR-07`, transfer connection `TC-4`, hold tank
  `HT-04`, sample results, maintenance and personnel paths, release controls,
  four deficiencies, and the CAPA feedback loop. The spatial arrangement and
  support-room adjacency are explicitly labeled as synthetic and not to scale.
- An original synthetic inspection image showing uneven gasket seating at
  `TC-4`.
- An original synthetic inspection image showing the pressure-hold verification
  station and incomplete-record context.

Generate the report from the repository root:

```bash
uv run python generation/scripts/generate_gmp_inspection_report.py
```

The generator validates the report against the pinned invoice and operational
evidence, renders a clean HTML preview, and then rasterizes all ten pages into an
image-only PDF. The PDF intentionally has no text layer so ingestion requires
OCR and the attachment figure and photographs remain meaningful extraction
targets.

### Generated GMP inspection report PDF

- [GMP-INS-BPB-2027-01.pdf](../sample-data/pdfs/GMP-INS-BPB-2027-01.pdf) —
  ten-page scanned inspection packet corresponding to the
  [BluePeak invoice](../sample-data/json/waypoint-supplier-invoices.json#L687) and
  [contamination evidence](../sample-data/json/supplier-evidence.json#L76).

## Oral solid dose procurement chain

The procurement package is a fictional, internally consistent sourcing chain
for `CALD-201` 50 mg film-coated tablets. Its three bidder roles use canonical
Waypoint supplier identities:

- Aster Ridge Biomanufacturing (`sup-001`) offers the strongest capacity and
  quality profile at the highest evaluated cost.
- Summit Dose Manufacturing (`sup-006`) offers adequate reserved capacity,
  satisfactory audit status, no open quality actions, and the best total value.
- Atlas Regional Manufacturing (`sup-014`) offers the shortest lead time but
  cannot firmly reserve the full monthly requirement.

Shared identifiers connect one RFP, three responses, three pre-existing
framework agreements, the Summit Dose award amendment, and the resulting
purchase order. The canonical synthetic extension is
[procurement-chain.json](../sample-data/json/procurement-chain.json).

The document structures are informed by the World Bank health-sector goods
bidding document, an SEC-filed pharmaceutical manufacturing agreement and its
amendment, FDA quality-agreement guidance, and GSA purchase-order field
conventions. The precise adaptation boundaries and public links are recorded in
[template-references.md](template-references.md). All Caldova terms, product
facts, commitments, people, scores, prices, and outcomes are original fictional
demo data rather than copied case facts or legal language.

The searchable PDFs include labeled figures for diagram-ingestion scenarios:

- The RFP contains a sourcing-to-supply lifecycle diagram.
- Each response contains an OSD manufacturing-control flow and a technology-
  transfer timeline.
- Each agreement contains a batch-evidence flow.
- The amendment contains a technology-transfer milestone flow.
- The purchase order contains a document-authority chain.

The RFP also contains an original synthetic OSD manufacturing-suite image
generated with MAI-Image-2.5. It is illustrative and does not depict a real
Caldova or supplier facility.

Generate all nine HTML previews and searchable PDFs from the repository root:

```bash
uv run python generation/scripts/generate_procurement_documents.py
```

The generator checks bidder count, evaluation weights, weighted scores, annual
price arithmetic, award uniqueness, document chronology, selected-supplier
references, amendment authority, and purchase-order totals before rendering.

### Generated procurement PDFs

| PDF | Role in the retrieval chain |
| --- | --- |
| [RFP-CAL-OSD-2026-01.pdf](../sample-data/pdfs/RFP-CAL-OSD-2026-01.pdf) | Caldova requirements, mandatory gates, award weights, schedule, and bid forms. |
| [RSP-AST-2026-01.pdf](../sample-data/pdfs/RSP-AST-2026-01.pdf) | Aster Ridge's high-capacity, high-quality, higher-cost offer. |
| [RSP-SUM-2026-01.pdf](../sample-data/pdfs/RSP-SUM-2026-01.pdf) | Summit Dose's selected best-total-value offer and proposed testing subcontractor. |
| [RSP-ATL-2026-01.pdf](../sample-data/pdfs/RSP-ATL-2026-01.pdf) | Atlas Regional's fast-transfer offer with a material firm-capacity exception. |
| [MSA-CAL-AST-2024-011.pdf](../sample-data/pdfs/MSA-CAL-AST-2024-011.pdf) | Existing Aster Ridge framework manufacturing agreement. |
| [MSA-CAL-SUM-2024-017.pdf](../sample-data/pdfs/MSA-CAL-SUM-2024-017.pdf) | Existing Summit Dose framework manufacturing agreement later amended for `CALD-201`. |
| [MSA-CAL-ATL-2025-004.pdf](../sample-data/pdfs/MSA-CAL-ATL-2025-004.pdf) | Existing Atlas Regional framework manufacturing agreement. |
| [AMD-MSA-SUM-2026-01.pdf](../sample-data/pdfs/AMD-MSA-SUM-2026-01.pdf) | Award record adding product, capacity, price, safety-stock, transfer, and subcontractor terms to the Summit Dose agreement. |
| [PO-CAL-SUM-2026-1108.pdf](../sample-data/pdfs/PO-CAL-SUM-2026-1108.pdf) | Initial `$398,680` Summit Dose order for technology transfer and two 480,000-tablet batches. |

## Complex diagram scenarios

Three information-dense visuals support different diagram-retrieval tests:

- [CAL-MAP-SUP-001.pdf](../sample-data/pdfs/CAL-MAP-SUP-001.pdf) tests
  geographic and entity-resolution reasoning. Its side-by-side atlas shows the
  canonical `sup-001`–`sup-015` supplier portfolio and highlights the three
  `CALD-201` bidders alongside Caldova's two purchase-order locations. Supplier
  names and billing locations are derived from the canonical invoice JSON.
  Markers and coastlines use the same equirectangular coordinate system. The base map is generated from
  public-domain [Natural Earth](https://www.naturalearthdata.com/) 1:110m land
  data. Generation fails if any configured location falls outside the source
  land polygons.
- [CAL-MAP-EVD-001.pdf](../sample-data/pdfs/CAL-MAP-EVD-001.pdf) tests
  cross-document relationship reasoning. It links policy and requisition
  authority to the RFP, three pre-existing agreements, three responses, the
  weighted evaluation, mandatory gates, executive approval, Summit Dose amendment,
  purchase order, transfer milestones, batches, release evidence, and delivery.
  Line styles distinguish authority, supporting evidence, and the selected path.
- Page 8 of
  [GMP-INS-BPB-2027-01.pdf](../sample-data/pdfs/GMP-INS-BPB-2027-01.pdf)
  tests OCR-based spatial, process, and risk reasoning. It combines facility
  zones, multiple flow types, sample locations, the suspected contamination
  route, finding markers, release controls, and CAPA feedback in the report's
  image-only scanned format.

Generate the two standalone searchable diagram PDFs from the repository root:

```bash
uv run python generation/scripts/generate_complex_diagrams.py
```

The generator validates the CALD-201 bidder set against the procurement source
and the complete Waypoint supplier set against the pinned invoice source before
rendering. The maps are original fictional demonstration artifacts and are not
adapted from the attached Zava reference poster.
