"""Create the Caldova Supplier Ontology (Fabric IQ) over the supplier lakehouse.

Fabric IQ Ontology is a PREVIEW feature. This script creates the ontology *structure*
(entity types, relationships, data bindings) over the CaldovaSupplierAnalytics lakehouse
tables via the Fabric REST API, matching the shape the portal "Generate Ontology"
produces.

    Supplier --locatedIn--> Location
    Supplier --hasInspectionResult--> InspectionResult
    Supplier --hasAuditResult--> AuditResult
    Supplier --hasFinancialRating--> FinancialRating

IMPORTANT - one manual step remains (preview limitation):
  The graph "build" that makes the ontology query-ready (queryReadiness -> Ready) is
  NOT exposed through the public Fabric REST API today. After running this script, once,
  in the Fabric portal:
    1. Open the ontology item and **Publish** it (builds the graph / loads data).
    2. Open SupplierDataAgent -> **Add data source** -> select the ontology.
  This is a one-time presenter step; all attendees then share the same Data Agent.

  The most reliable path is the portal one-click:
    Fabric workspace -> SupplierSM -> ribbon **Generate Ontology** -> name it -> Create.

Env vars (all required except ONTOLOGY_NAME; seed.ps1 sets them for you):
  FABRIC_WORKSPACE_ID   Fabric workspace containing the supplier model + lakehouse (required)
  FABRIC_LAKEHOUSE_ID   CaldovaSupplierAnalytics item id (required; seed.ps1 discovers it by name)
  ONTOLOGY_NAME         Ontology display name (letters/numbers/underscore only; default CaldovaSupplierOntology)
"""
import base64
import json
import os
import random
import subprocess
import time
import uuid

import requests

# These MUST come from the environment so the ontology binds to YOUR deployment's
# workspace + lakehouse. seed.ps1 discovers the CaldovaSupplierAnalytics lakehouse by
# name and sets FABRIC_LAKEHOUSE_ID before calling this script. Fail loudly rather than
# silently defaulting to someone else's resources.
WORKSPACE_ID = os.getenv("FABRIC_WORKSPACE_ID")
LAKEHOUSE_ID = os.getenv("FABRIC_LAKEHOUSE_ID")
ONTOLOGY_NAME = os.getenv("ONTOLOGY_NAME", "CaldovaSupplierOntology")

if not WORKSPACE_ID or not LAKEHOUSE_ID:
    raise SystemExit(
        "FABRIC_WORKSPACE_ID and FABRIC_LAKEHOUSE_ID are required. Run via "
        "infra/scripts/seed.ps1 (which discovers the lakehouse by name), or set both "
        "env vars manually (FABRIC_LAKEHOUSE_ID = the CaldovaSupplierAnalytics lakehouse GUID)."
    )


# Match the portal-generated definition exactly: every part carries a $schema and
# LakehouseTable bindings use sourceSchema=null (NOT "dbo").
SCHEMA_BASE = "https://developer.microsoft.com/json-schemas/fabric/item/ontology"
_used = set()


def new_int_id() -> str:
    while True:
        v = random.randint(10**12, 10**18)
        if v not in _used:
            _used.add(v)
            return str(v)


def b64(obj) -> str:
    return base64.b64encode(json.dumps(obj).encode("utf-8")).decode("ascii")


def prop(name, value_type):
    return {"id": new_int_id(), "name": name, "redefines": None,
            "baseTypeNamespaceType": None, "valueType": value_type, "_name": name}


def make_entity(name, table, key_prop, display_prop, props):
    plist = [prop(n, vt) for (n, vt) in props]
    by_name = {p["_name"]: p for p in plist}
    etid = new_int_id()
    entity_def = {
        "$schema": f"{SCHEMA_BASE}/entityType/1.0.0/schema.json",
        "id": etid, "namespace": "usertypes", "baseEntityTypeId": None, "name": name,
        "entityIdParts": [by_name[key_prop]["id"]],
        "displayNamePropertyId": by_name[display_prop]["id"],
        "namespaceType": "Custom", "visibility": "Visible",
        "properties": [{k: v for k, v in p.items() if k != "_name"} for p in plist],
        "timeseriesProperties": [], "untypedProperties": [],
    }
    binding = {
        "$schema": f"{SCHEMA_BASE}/dataBinding/1.0.0/schema.json",
        "id": str(uuid.uuid4()),
        "dataBindingConfiguration": {
            "dataBindingType": "NonTimeSeries",
            "propertyBindings": [
                {"sourceColumnName": p["_name"], "targetPropertyId": p["id"]}
                for p in plist
            ],
            "sourceTableProperties": {
                "sourceType": "LakehouseTable", "workspaceId": WORKSPACE_ID,
                "itemId": LAKEHOUSE_ID, "sourceTableName": table, "sourceSchema": None,
            },
        },
    }
    return {"id": etid, "def": entity_def, "binding": binding, "by_name": by_name}


def make_rel(name, src, tgt, ctx_table, src_col, src_key, tgt_col, tgt_key):
    rid = new_int_id()
    rel_def = {
        "$schema": f"{SCHEMA_BASE}/relationshipType/1.0.0/schema.json",
        "namespace": "usertypes", "id": rid, "name": name, "namespaceType": "Custom",
        "source": {"entityTypeId": src["id"]}, "target": {"entityTypeId": tgt["id"]},
    }
    ctx = {
        "$schema": f"{SCHEMA_BASE}/contextualization/1.0.0/schema.json",
        "id": str(uuid.uuid4()),
        "dataBindingTable": {
            "workspaceId": WORKSPACE_ID, "itemId": LAKEHOUSE_ID,
            "sourceTableName": ctx_table, "sourceSchema": None, "sourceType": "LakehouseTable",
        },
        "sourceKeyRefBindings": [
            {"sourceColumnName": src_col, "targetPropertyId": src["by_name"][src_key]["id"]}
        ],
        "targetKeyRefBindings": [
            {"sourceColumnName": tgt_col, "targetPropertyId": tgt["by_name"][tgt_key]["id"]}
        ],
    }
    return {"id": rid, "def": rel_def, "ctx": ctx}


# Entity properties bind ONLY to columns that exist in the bound table (DimSupplier for
# the supplier entity). Performance metrics live in SupplierPerformance and are reached
# through the relationship context tables, not stored on the Supplier entity.
supplier = make_entity("Supplier", "DimSupplier", "SupplierID", "SupplierName",
                       [("SupplierID", "String"), ("SupplierName", "String"),
                        ("ServiceCategory", "String"), ("ExperienceYears", "BigInt"),
                        ("AvailableCapacityKPerMonth", "BigInt"), ("MOQKUnits", "BigInt"),
                        ("RegulatoryInspections3yr", "BigInt"),
                        ("FinancialStabilityRating", "String")])
location = make_entity("Location", "DimLocation", "LocationID", "Location",
                       [("LocationID", "String"), ("Location", "String"),
                        ("StateOrRegion", "String"), ("Country", "String")])
inspection = make_entity("InspectionResult", "DimInspectionResult", "ResultCode", "ResultName",
                         [("ResultCode", "String"), ("ResultName", "String"),
                          ("Description", "String"), ("SeverityRank", "BigInt"),
                          ("IsDisqualifying", "Boolean")])
audit = make_entity("AuditResult", "DimAuditResult", "AuditResult", "AuditResult",
                    [("AuditResult", "String"), ("ResultRank", "BigInt"),
                     ("IsPassing", "Boolean")])
finrating = make_entity("FinancialRating", "DimFinancialRating", "Rating", "Rating",
                        [("Rating", "String"), ("RatingRank", "BigInt"),
                         ("InvestmentGrade", "Boolean")])
entities = [supplier, location, inspection, audit, finrating]
rels = [
    make_rel("locatedIn", supplier, location, "DimSupplier",
             "SupplierID", "SupplierID", "LocationID", "LocationID"),
    make_rel("hasInspectionResult", supplier, inspection, "SupplierPerformance",
             "SupplierID", "SupplierID", "LastRegulatoryInspection", "ResultCode"),
    make_rel("hasAuditResult", supplier, audit, "SupplierPerformance",
             "SupplierID", "SupplierID", "LastInternalAuditResult", "AuditResult"),
    make_rel("hasFinancialRating", supplier, finrating, "SupplierPerformance",
             "SupplierID", "SupplierID", "FinancialStabilityRating", "Rating"),
]

parts = [
    {"path": ".platform",
     "payload": b64({"$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
                     "metadata": {"type": "Ontology", "displayName": ONTOLOGY_NAME},
                     "config": {"version": "2.0", "logicalId": "00000000-0000-0000-0000-000000000000"}}),
     "payloadType": "InlineBase64"},
    {"path": "definition.json", "payload": b64({}), "payloadType": "InlineBase64"},
]
for e in entities:
    parts.append({"path": f"EntityTypes/{e['id']}/definition.json",
                  "payload": b64(e["def"]), "payloadType": "InlineBase64"})
    parts.append({"path": f"EntityTypes/{e['id']}/DataBindings/{e['binding']['id']}.json",
                  "payload": b64(e["binding"]), "payloadType": "InlineBase64"})
for r in rels:
    parts.append({"path": f"RelationshipTypes/{r['id']}/definition.json",
                  "payload": b64(r["def"]), "payloadType": "InlineBase64"})
    parts.append({"path": f"RelationshipTypes/{r['id']}/Contextualizations/{r['ctx']['id']}.json",
                  "payload": b64(r["ctx"]), "payloadType": "InlineBase64"})


def main():
    tok = subprocess.run(
        ["az", "account", "get-access-token", "--resource",
         "https://api.fabric.microsoft.com", "--query", "accessToken", "-o", "tsv"],
        capture_output=True, text=True, shell=True).stdout.strip()
    url = f"https://api.fabric.microsoft.com/v1/workspaces/{WORKSPACE_ID}/ontologies"
    body = {"displayName": ONTOLOGY_NAME,
            "description": "Caldova supplier ontology (suppliers, sites, inspections, audits, financials).",
            "definition": {"parts": parts}}
    print(f"Creating ontology '{ONTOLOGY_NAME}' ({len(entities)} entities, "
          f"{len(rels)} relationships)...")
    r = requests.post(url, headers={"Authorization": f"Bearer {tok}",
                                    "Content-Type": "application/json"}, json=body)
    print("STATUS", r.status_code)
    if r.status_code == 202:
        op = r.headers.get("Location")
        for i in range(30):
            time.sleep(8)
            if op:
                st = requests.get(op, headers={"Authorization": f"Bearer {tok}"}).json().get("status")
                print(f"  poll {i}: {st}")
                if str(st).lower() in ("succeeded", "completed", "failed"):
                    break
    elif r.status_code not in (200, 201):
        print("BODY:", r.text[:1000])
    print("\nDONE. Remaining manual step (preview): open the ontology in the Fabric "
          "portal and Publish it, then add it as a SupplierDataAgent data source. "
          "See this file's module docstring.")


if __name__ == "__main__":
    main()
