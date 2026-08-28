#!/usr/bin/env python
"""Build (refresh) the Fabric IQ ontology graph so it can answer queries.

Creating an ontology with the upstream ``create_fabric_ontology.py`` materializes a
GraphModel, but that graph starts **empty**. Until it is refreshed, the Data Agent
answers ontology questions with:

    "The graph model required to answer this query is currently unavailable."

The upstream provisioning does not trigger this refresh, so this repo runs it as a
post-step (``infra/scripts/seed.ps1``). It is a normal Fabric job -- no portal step.

Auth uses ``AzureDeveloperCliCredential`` to match the upstream scripts, so
``azd auth login`` must be signed in to the Fabric tenant.

Reads FABRIC_TENANT_ID / FABRIC_WORKSPACE_ID / FABRIC_ONTOLOGY_ID from the upstream
``data/caldova-upstream/.env`` (written by the provision scripts).
"""

from __future__ import annotations

import os
import sys
import time
from pathlib import Path

import httpx
from azure.identity import AzureCliCredential as AzureDeveloperCliCredential  # az is reliable inside the azd hook (azd auth token can time out there)
from dotenv import load_dotenv

REPO_ROOT = Path(__file__).resolve().parents[2]
ENV_PATH = REPO_ROOT / "data" / "caldova-upstream" / ".env"
FABRIC_API = "https://api.fabric.microsoft.com"
TERMINAL = {"Completed", "Succeeded", "Failed", "Cancelled", "Deduped"}


def require(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise SystemExit(
            f"{name} is required. Run the Fabric provision scripts first "
            f"(they write it to {ENV_PATH})."
        )
    return value


def main() -> int:
    load_dotenv(ENV_PATH, override=True)
    tenant_id = require("FABRIC_TENANT_ID")
    workspace_id = require("FABRIC_WORKSPACE_ID")
    ontology_id = require("FABRIC_ONTOLOGY_ID")

    credential = AzureDeveloperCliCredential(tenant_id=tenant_id)
    try:
        token = credential.get_token(f"{FABRIC_API}/.default").token
    finally:
        credential.close()

    with httpx.Client(
        base_url=FABRIC_API, timeout=180, headers={"Authorization": f"Bearer {token}"}
    ) as client:
        items = client.get(f"/v1/workspaces/{workspace_id}/items").json()["value"]
        # The generated graph model is named "<ontology display name>_graph_<id-without-dashes>".
        suffix = ontology_id.replace("-", "")
        graph = next(
            (
                item
                for item in items
                if item["type"] == "GraphModel" and suffix in item["displayName"]
            ),
            None,
        )
        if graph is None:
            raise SystemExit(
                f"No GraphModel found for ontology {ontology_id} in workspace {workspace_id}."
            )
        print(f"Graph model: {graph['displayName']} ({graph['id']})")

        jobs_url = f"/v1/workspaces/{workspace_id}/items/{graph['id']}/jobs/instances"
        in_progress = {"NotStarted", "InProgress", "Running"}

        def refresh_jobs():
            return client.get(jobs_url).json().get("value", [])

        # Only start a new refresh if one is not already running -- Fabric rejects
        # concurrent refreshes with RefreshAlreadyInProgress. Re-running the seed (or a
        # prior attempt) can leave a refresh in flight, so wait for it instead of failing.
        if any(j.get("status") in in_progress for j in refresh_jobs()):
            print("A graph refresh is already in progress; waiting for it to finish...")
        else:
            response = client.post(
                f"/v1/workspaces/{workspace_id}/graphModels/{graph['id']}/jobs/refreshGraph/instances"
            )
            if response.status_code not in (200, 201, 202) and "RefreshAlreadyInProgress" not in response.text:
                raise SystemExit(
                    f"refreshGraph failed: HTTP {response.status_code} {response.text[:300]}"
                )
            print("Refresh accepted; waiting for the graph build...")

        for attempt in range(1, 61):
            time.sleep(10)
            jobs = refresh_jobs()
            if any(j.get("status") in in_progress for j in jobs):
                if attempt % 3 == 0:
                    print(f"  refresh in progress ({attempt}/60)...")
                continue
            # No refresh running now -- evaluate the latest attempt that actually ran,
            # ignoring jobs that were rejected with RefreshAlreadyInProgress.
            real = [
                j for j in jobs
                if "RefreshAlreadyInProgress" not in str(j.get("failureReason") or "")
            ]
            if real:
                latest = max(real, key=lambda j: j.get("startTimeUtc") or "")
                status = latest.get("status")
                if status in ("Failed", "Cancelled"):
                    raise SystemExit(f"Graph refresh {status}: {latest.get('failureReason')}")
                if status in TERMINAL:
                    print(f"Graph refresh {status}.")
                    print(
                        "The ontology is now queryable. The first Data Agent question after a "
                        "refresh can still cold-start -- ask one throwaway question before demoing."
                    )
                    return 0
            if attempt % 3 == 0:
                print(f"  waiting for the graph refresh ({attempt}/60)...")

    raise SystemExit("Timed out waiting for the graph refresh to finish.")


if __name__ == "__main__":
    sys.exit(main())
