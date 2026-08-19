"""Seed the Caldova document knowledge sources for Foundry IQ (multi-source KB).

This EXTENDS the existing ``caldova-supply-kb`` with document-grounding sources built
from the upstream Caldova corpus (``data/caldova-upstream/sample-data``). It is
deliberately **additive and parallel-safe**:

  * The existing ``caldova-supply-policies`` index / knowledge source / KB are NOT
    modified by default. This script only creates NEW ``caldova-supply-*`` indexes and
    knowledge sources.
  * The new sources are inert until you attach them, so the live agent's retrieval is
    unchanged until you deliberately run with ``--attach-to-kb``.

Design boundary (keep Fabric IQ and Foundry IQ from overlapping):
  * Fabric IQ owns the NUMBERS  -> supplier KPIs, rankings, trends (SupplierSM /
    SupplierDataAgent). We never index ``supplier-kpi-profiles.json`` or invoices here.
  * Foundry IQ owns the DOCUMENTS -> policies, contracts, quality findings, cold-chain
    investigations. That is exactly what this script indexes.

Three new document knowledge sources:
  * ``caldova-supply-procurement`` -> RFP, bidder responses, MSAs, amendment, PO, and the
    global purchasing policy (the governance behind sourcing).
  * ``caldova-supply-quality``     -> GMP inspection, CoA, nonconformance, deviation,
    yield, and final-inspection reports.
  * ``caldova-supply-coldchain``   -> temperature-logger report and excursion
    investigation (grounds the Maria Garcia cold-chain escalation).

The single image-only PDF (GMP inspection) is indexed from its structured JSON twin.

Auth uses ``DefaultAzureCredential`` (``az login``) for the Search data plane
(``https://search.azure.com/.default``). The caller needs Search Service Contributor +
Search Index Data Contributor on the Search service.

Environment:
  AZURE_AI_SEARCH_SERVICE_ENDPOINT   https://<service>.search.windows.net   (required)
  FOUNDRYIQ_KB_NAME                  KB name (default caldova-supply-kb)
  KB_API_VERSION                     Search api-version (default 2026-05-01-preview)

Usage:
  python infra/scripts/seed-foundryiq-docs.py                 # build indexes + sources
  python infra/scripts/seed-foundryiq-docs.py --attach-to-kb  # also add them to the KB
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

import httpx
from azure.identity import DefaultAzureCredential
from pypdf import PdfReader

REPO_ROOT = Path(__file__).resolve().parents[2]
PDF_DIR = REPO_ROOT / "data" / "caldova-upstream" / "sample-data" / "pdfs"
JSON_DIR = REPO_ROOT / "data" / "caldova-upstream" / "sample-data" / "json"

SEARCH_ENDPOINT = os.environ.get("AZURE_AI_SEARCH_SERVICE_ENDPOINT", "").rstrip("/")
KB_NAME = os.environ.get("FOUNDRYIQ_KB_NAME", "caldova-supply-kb")
API_VERSION = os.environ.get("KB_API_VERSION", "2026-05-01-preview")

CHUNK_CHARS = 1500
CHUNK_OVERLAP = 150

# Human-readable titles per document stem (from the upstream corpus catalogue).
DOC_TITLES = {
    "RFP-CAL-OSD-2026-01": "RFP CALD-201 - requirements, mandatory gates, award weights, schedule",
    "RSP-AST-2026-01": "Aster Ridge - RFP response",
    "RSP-SUM-2026-01": "Summit Dose - RFP response (selected bidder)",
    "RSP-ATL-2026-01": "Atlas Regional - RFP response (firm-capacity exception)",
    "MSA-CAL-AST-2024-011": "Aster Ridge - master manufacturing agreement",
    "MSA-CAL-SUM-2024-017": "Summit Dose - master manufacturing agreement",
    "MSA-CAL-ATL-2025-004": "Atlas Regional - master manufacturing agreement",
    "AMD-MSA-SUM-2026-01": "Summit Dose - award amendment for CALD-201",
    "PO-CAL-SUM-2026-1108": "Summit Dose - purchase order (tech transfer + two batches)",
    "CAL-POL-PUR-001": "Caldova global purchasing policy",
    "GMP-INS-BPB-2027-01": "BluePeak Biologics - GMP supplier-quality inspection, findings and CAPA",
    "COA-MD-1026-A": "Meridian lot LOT-MD-1026-A - certificate of analysis",
    "NCR-KDA-1026-07": "Keystone - nonconformance and scrap disposition",
    "DEV-BPB-1026": "BluePeak - contamination deviation investigation",
    "YLD-MAW-1026": "Meridian AUR-API-7 - lot yield worksheet",
    "YTA-MAW-1026-04": "Meridian - yield true-up assessment",
    "FIR-KDA-1026": "Keystone auto-injector - final inspection report",
    "UTL-BPB-1026": "BluePeak - bioreactor utilization and run log",
    "TL-VCL-1026": "Shipment SHIP-VC-1026-BOS-FRA - temperature logger report",
    "EXC-VC-1026-04": "Shipment SHIP-VC-1026-BOS-FRA - temperature excursion investigation",
}

# Source groups. Each stem is a PDF unless listed in JSON_BACKED.
SOURCES: dict[str, dict] = {
    "caldova-supply-procurement": {
        "description": "Caldova procurement corpus: RFP CALD-201, bidder responses, master "
        "manufacturing agreements, the Summit Dose award amendment and purchase order, and "
        "the global purchasing policy that governs sourcing decisions.",
        "stems": [
            "RFP-CAL-OSD-2026-01",
            "RSP-AST-2026-01",
            "RSP-SUM-2026-01",
            "RSP-ATL-2026-01",
            "MSA-CAL-AST-2024-011",
            "MSA-CAL-SUM-2024-017",
            "MSA-CAL-ATL-2025-004",
            "AMD-MSA-SUM-2026-01",
            "PO-CAL-SUM-2026-1108",
            "CAL-POL-PUR-001",
        ],
    },
    "caldova-supply-quality": {
        "description": "Caldova supplier quality and compliance evidence: GMP inspection "
        "findings and CAPA, certificate of analysis, nonconformance and scrap disposition, "
        "contamination deviation, yield worksheets, and final-inspection reports.",
        "stems": [
            "GMP-INS-BPB-2027-01",
            "COA-MD-1026-A",
            "NCR-KDA-1026-07",
            "DEV-BPB-1026",
            "YLD-MAW-1026",
            "YTA-MAW-1026-04",
            "FIR-KDA-1026",
            "UTL-BPB-1026",
        ],
    },
    "caldova-supply-coldchain": {
        "description": "Caldova cold-chain logistics evidence for shipment "
        "SHIP-VC-1026-BOS-FRA: temperature-logger report and the temperature excursion "
        "investigation, quality event EXC-VC-1026.",
        "stems": ["TL-VCL-1026", "EXC-VC-1026-04"],
    },
}

# Stems whose PDF has no extractable text -> index the structured JSON twin instead.
JSON_BACKED = {"GMP-INS-BPB-2027-01"}


def _chunks(text: str) -> list[str]:
    text = " ".join(text.split())
    if not text:
        return []
    out: list[str] = []
    start = 0
    while start < len(text):
        end = min(start + CHUNK_CHARS, len(text))
        out.append(text[start:end])
        if end >= len(text):
            break
        start = end - CHUNK_OVERLAP
    return out


def _flatten_json(obj, prefix: str = "") -> list[str]:
    lines: list[str] = []
    if isinstance(obj, dict):
        for k, v in obj.items():
            lines.extend(_flatten_json(v, f"{prefix}{k}: " if not prefix else f"{prefix}{k}: "))
    elif isinstance(obj, list):
        for item in obj:
            lines.extend(_flatten_json(item, prefix))
    else:
        lines.append(f"{prefix}{obj}".strip())
    return lines


def _doc_text(stem: str) -> str:
    """Return the best available text for a document stem (JSON twin or PDF)."""
    if stem in JSON_BACKED:
        jpath = JSON_DIR / f"{stem}.json"
        data = json.loads(jpath.read_text(encoding="utf-8"))
        return "\n".join(_flatten_json(data))
    reader = PdfReader(str(PDF_DIR / f"{stem}.pdf"))
    return "\n".join((page.extract_text() or "") for page in reader.pages)


def _docs_for_source(stems: list[str]) -> list[dict[str, str]]:
    docs: list[dict[str, str]] = []
    for stem in stems:
        title = DOC_TITLES.get(stem, stem)
        source = f"{stem}.json" if stem in JSON_BACKED else f"{stem}.pdf"
        text = _doc_text(stem)
        chunks = _chunks(text)
        if not chunks:
            print(f"  WARNING: no text extracted for {stem}; skipping")
            continue
        for i, chunk in enumerate(chunks):
            docs.append(
                {
                    "id": f"{stem}-{i}",
                    "title": title if i == 0 else f"{title} (cont. {i})",
                    "source": source,
                    "content": chunk,
                }
            )
    return docs


def _put(client: httpx.Client, path: str, body: dict) -> None:
    url = f"{SEARCH_ENDPOINT}/{path}?api-version={API_VERSION}"
    r = client.put(url, json=body)
    if r.status_code >= 400:
        raise SystemExit(f"PUT {path} failed {r.status_code}: {r.text}")


def _index_body(name: str) -> dict:
    return {
        "name": name,
        "fields": [
            {"name": "id", "type": "Edm.String", "key": True, "filterable": True},
            {"name": "title", "type": "Edm.String", "searchable": True},
            {"name": "source", "type": "Edm.String", "filterable": True, "facetable": True},
            {"name": "content", "type": "Edm.String", "searchable": True},
        ],
        "semantic": {
            "configurations": [
                {
                    "name": "default",
                    "prioritizedFields": {
                        "titleField": {"fieldName": "title"},
                        "prioritizedContentFields": [{"fieldName": "content"}],
                    },
                }
            ]
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--attach-to-kb",
        action="store_true",
        help="Also add the new sources to the knowledge base (changes live retrieval).",
    )
    args = parser.parse_args()

    if not SEARCH_ENDPOINT:
        raise SystemExit("AZURE_AI_SEARCH_SERVICE_ENDPOINT is required.")
    if not PDF_DIR.exists():
        raise SystemExit(f"Upstream PDF folder not found: {PDF_DIR}")

    credential = DefaultAzureCredential()
    token = credential.get_token("https://search.azure.com/.default").token
    with httpx.Client(timeout=180, headers={"Authorization": f"Bearer {token}"}) as client:
        for source_name, spec in SOURCES.items():
            index_name = source_name
            ks_name = f"{source_name}-ks"
            docs = _docs_for_source(spec["stems"])
            print(f"\n[{source_name}] {len(docs)} chunks from {len(spec['stems'])} documents")

            _put(client, f"indexes/{index_name}", _index_body(index_name))
            r = client.post(
                f"{SEARCH_ENDPOINT}/indexes/{index_name}/docs/index?api-version={API_VERSION}",
                json={"value": [{"@search.action": "mergeOrUpload", **d} for d in docs]},
            )
            if r.status_code >= 400:
                raise SystemExit(f"Doc upload to {index_name} failed {r.status_code}: {r.text}")
            print(f"  index + {len(docs)} docs uploaded: {index_name}")

            ks_body = {
                "name": ks_name,
                "kind": "searchIndex",
                "description": spec["description"],
                "searchIndexParameters": {
                    "searchIndexName": index_name,
                    "semanticConfigurationName": "default",
                    "sourceDataFields": [{"name": "title"}, {"name": "source"}],
                    "searchFields": [{"name": "title"}, {"name": "content"}],
                },
            }
            _put(client, f"knowledgeSources/{ks_name}", ks_body)
            print(f"  knowledge source: {ks_name}")

        if args.attach_to_kb:
            url = f"{SEARCH_ENDPOINT}/knowledgeBases/{KB_NAME}?api-version={API_VERSION}"
            kb = client.get(url).json()
            existing = {s["name"] for s in kb.get("knowledgeSources", [])}
            wanted = [f"{name}-ks" for name in SOURCES]
            for ks in wanted:
                if ks not in existing:
                    kb.setdefault("knowledgeSources", []).append({"name": ks})
            for noise in ("@odata.context", "@odata.etag"):
                kb.pop(noise, None)
            r = client.put(url, json=kb)
            if r.status_code >= 400:
                raise SystemExit(f"KB update failed {r.status_code}: {r.text}")
            print(f"\nAttached to KB '{KB_NAME}': {[s['name'] for s in kb['knowledgeSources']]}")
        else:
            print(
                f"\nSources built (inert). To make them live in the agent, run again with "
                f"--attach-to-kb (adds them to '{KB_NAME}')."
            )


if __name__ == "__main__":
    main()
