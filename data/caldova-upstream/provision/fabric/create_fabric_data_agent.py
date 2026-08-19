"""Create and publish the Caldova supplier analytics Fabric Data Agent."""

import argparse
import os
import time
from pathlib import Path

import httpx
from azure.identity import AzureDeveloperCliCredential
from dotenv import load_dotenv

REPO_ROOT = Path(__file__).parents[2]
ENV_PATH = REPO_ROOT / ".env"
FABRIC_API_URL = "https://api.fabric.microsoft.com"
FABRIC_SCOPE = f"{FABRIC_API_URL}/.default"
SEMANTIC_MODEL_NAME = "SupplierSM"
DATA_AGENT_NAME = "SupplierDataAgent"
OPERATION_TIMEOUT_SECONDS = 300
EXPECTED_TABLES = {
    "DimAuditResult",
    "DimDate",
    "DimFinancialRating",
    "DimInspectionResult",
    "DimLocation",
    "DimSupplier",
    "SupplierPerformance",
}
AI_INSTRUCTIONS = """Use SupplierSM to answer questions about Caldova suppliers,
service categories, locations, capacity, quality, regulatory status, commercial
metrics, and weekly performance trends. Supplier identity comes from the canonical
Waypoint invoice corpus. Performance metrics are fictional synthetic analytics and
must not be described as facts extracted from invoices. Treat null manufacturing
metrics as not applicable, never as zero. Use latest and four-week change measures
for current status and recent movement.
"""


def require_env(name: str) -> str:
    """Return a required environment setting."""
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"{name} is required for Fabric deployment.")
    return value


def request(
    client: httpx.Client,
    method: str,
    url: str,
    *,
    expected_statuses: set[int],
    json_body: dict | None = None,
    params: dict[str, str] | None = None,
) -> httpx.Response:
    """Send one Fabric request and enforce its response status."""
    response = client.request(method, url, json=json_body, params=params)
    if response.status_code not in expected_statuses:
        response.raise_for_status()
        raise RuntimeError(f"Unexpected Fabric status {response.status_code}: {method} {url}")
    return response


def wait_for_operation(client: httpx.Client, response: httpx.Response) -> None:
    """Wait for a Fabric long-running operation."""
    if response.status_code != httpx.codes.ACCEPTED:
        return
    operation_url = response.headers.get("Location")
    if not operation_url:
        raise RuntimeError("Fabric returned 202 without an operation location.")
    deadline = time.monotonic() + OPERATION_TIMEOUT_SECONDS
    while time.monotonic() < deadline:
        operation = request(
            client, "GET", operation_url, expected_statuses={httpx.codes.OK}
        )
        payload = operation.json()
        if payload.get("status") == "Succeeded":
            return
        if payload.get("status") in {"Failed", "Cancelled"}:
            raise RuntimeError(f"Fabric operation failed: {payload}")
        time.sleep(min(max(float(operation.headers.get("Retry-After", "2")), 1), 10))
    raise TimeoutError("Timed out waiting for the Fabric operation.")


def list_items(client: httpx.Client, workspace_id: str, item_type: str) -> list[dict]:
    """List Fabric workspace items by API collection name."""
    response = request(
        client,
        "GET",
        f"/v1/workspaces/{workspace_id}/{item_type}",
        expected_statuses={httpx.codes.OK},
    )
    return response.json().get("value", [])


def find_semantic_model(client: httpx.Client, workspace_id: str) -> dict:
    """Find SupplierSM through the public Fabric API."""
    models = list_items(client, workspace_id, "semanticModels")
    model = next(
        (item for item in models if item.get("displayName") == SEMANTIC_MODEL_NAME),
        None,
    )
    if model is None:
        raise RuntimeError(f"Semantic model '{SEMANTIC_MODEL_NAME}' was not found.")
    return model


def get_or_create_agent(client: httpx.Client, workspace_id: str) -> dict:
    """Find or create SupplierDataAgent."""
    agents = list_items(client, workspace_id, "dataAgents")
    existing = next(
        (item for item in agents if item.get("displayName") == DATA_AGENT_NAME), None
    )
    if existing:
        return existing
    response = request(
        client,
        "POST",
        f"/v1/workspaces/{workspace_id}/dataAgents",
        expected_statuses={httpx.codes.OK, httpx.codes.CREATED, httpx.codes.ACCEPTED},
        json_body={"artifactType": "LLMPlugin", "displayName": DATA_AGENT_NAME},
    )
    wait_for_operation(client, response)
    for _ in range(30):
        agents = list_items(client, workspace_id, "dataAgents")
        created = next(
            (item for item in agents if item.get("displayName") == DATA_AGENT_NAME),
            None,
        )
        if created:
            return created
        time.sleep(2)
    raise RuntimeError(f"Data Agent '{DATA_AGENT_NAME}' was created but not found.")


def list_datasources(client: httpx.Client, base_url: str) -> list[dict]:
    """List staging data sources."""
    response = request(
        client,
        "GET",
        f"{base_url}/staging/datasources",
        expected_statuses={httpx.codes.OK},
    )
    return response.json().get("value", [])


def ensure_datasource(
    client: httpx.Client,
    base_url: str,
    workspace_id: str,
    semantic_model_id: str,
) -> dict:
    """Attach SupplierSM and return its staging data source."""
    for source in list_datasources(client, base_url):
        if source.get("itemReference", {}).get("itemId") == semantic_model_id:
            return source
    response = request(
        client,
        "POST",
        f"{base_url}/staging/datasources",
        expected_statuses={httpx.codes.OK, httpx.codes.CREATED, httpx.codes.ACCEPTED},
        json_body={
            "type": "FabricItem",
            "itemReference": {
                "referenceType": "ById",
                "itemId": semantic_model_id,
                "workspaceId": workspace_id,
            },
        },
    )
    wait_for_operation(client, response)
    return next(
        source
        for source in list_datasources(client, base_url)
        if source.get("itemReference", {}).get("itemId") == semantic_model_id
    )


def select_tables(client: httpx.Client, base_url: str, datasource_id: str) -> None:
    """Validate and select all SupplierSM tables."""
    elements_url = f"{base_url}/staging/datasources/{datasource_id}/elements"
    response = request(client, "GET", elements_url, expected_statuses={httpx.codes.OK})
    tables = {
        element["displayName"]: element
        for element in response.json().get("value", [])
        if element.get("type") == "Table"
    }
    if set(tables) != EXPECTED_TABLES:
        raise RuntimeError(
            f"SupplierSM tables differ. Expected {sorted(EXPECTED_TABLES)}, "
            f"found {sorted(tables)}."
        )
    for table_name in sorted(EXPECTED_TABLES):
        table = tables[table_name]
        if table.get("isSelected"):
            continue
        response = request(
            client,
            "PATCH",
            elements_url,
            expected_statuses={httpx.codes.OK, httpx.codes.ACCEPTED},
            params={"id": table["id"]},
            json_body={"isSelected": True},
        )
        wait_for_operation(client, response)


def deploy() -> None:
    """Configure and publish SupplierDataAgent."""
    load_dotenv(ENV_PATH, override=True)
    tenant_id = require_env("FABRIC_TENANT_ID")
    workspace_id = require_env("FABRIC_WORKSPACE_ID")
    credential = AzureDeveloperCliCredential(tenant_id=tenant_id)
    try:
        token = credential.get_token(FABRIC_SCOPE).token
    finally:
        credential.close()
    with httpx.Client(
        base_url=FABRIC_API_URL,
        headers={"Authorization": f"Bearer {token}"},
        timeout=60,
    ) as client:
        semantic_model = find_semantic_model(client, workspace_id)
        agent = get_or_create_agent(client, workspace_id)
        base_url = f"/v1/workspaces/{workspace_id}/dataAgents/{agent['id']}"
        response = request(
            client,
            "PATCH",
            f"{base_url}/staging/settings",
            expected_statuses={httpx.codes.OK, httpx.codes.ACCEPTED},
            json_body={"aiInstructions": AI_INSTRUCTIONS},
        )
        wait_for_operation(client, response)
        datasource = ensure_datasource(
            client, base_url, workspace_id, semantic_model["id"]
        )
        select_tables(client, base_url, datasource["id"])
        response = request(
            client,
            "POST",
            f"{base_url}/staging/publish",
            expected_statuses={httpx.codes.OK, httpx.codes.CREATED, httpx.codes.ACCEPTED},
            json_body={
                "publishedDescription": "Caldova supplier performance analytics agent"
            },
        )
        wait_for_operation(client, response)

    mcp_url = (
        f"{FABRIC_API_URL}/v1/mcp/workspaces/{workspace_id}"
        f"/dataagents/{agent['id']}/agent"
    )
    print(f"Data Agent: {DATA_AGENT_NAME} ({agent['id']})")
    print(f"MCP endpoint: {mcp_url}")


def main() -> None:
    """Optionally skip or deploy the paid-capacity Data Agent stage."""
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--skip",
        action="store_true",
        help="Skip the paid-capacity Data Agent stage explicitly.",
    )
    args = parser.parse_args()
    if args.skip:
        print("Skipping SupplierDataAgent deployment; Fabric deployment is partial.")
        return
    deploy()


if __name__ == "__main__":
    main()