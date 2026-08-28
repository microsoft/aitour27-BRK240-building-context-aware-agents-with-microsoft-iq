"""Create or update the Caldova Direct Lake supplier semantic model."""

import base64
import os
import time
import warnings
from pathlib import Path

from azure.identity import AzureCliCredential as AzureDeveloperCliCredential  # az is reliable inside the azd hook (azd auth token can time out there)
from dotenv import load_dotenv, set_key

warnings.filterwarnings("ignore", category=SyntaxWarning, module=r"microsoft_fabric_api\..*")

from microsoft_fabric_api import FabricClient  # noqa: E402
from microsoft_fabric_api.generated.semanticmodel.models import (  # noqa: E402
    CreateSemanticModelRequest,
    SemanticModelDefinition,
    SemanticModelDefinitionPart,
    UpdateSemanticModelDefinitionRequest,
)

REPO_ROOT = Path(__file__).parents[2]
ENV_PATH = REPO_ROOT / ".env"
DEFINITION_ROOT = (
    REPO_ROOT
    / "sample-data/fabric/Supply Chain Operations/SupplierSM (SemanticModel)"
)
LAKEHOUSE_NAME = "CaldovaSupplierAnalytics"
SEMANTIC_MODEL_NAME = "SupplierSM"
PORTAL_BASE_URL = "https://msit.powerbi.com"
SQL_ENDPOINT_TIMEOUT_SECONDS = 300


def require_env(name: str) -> str:
    """Return a required environment setting."""
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"{name} is required for Fabric deployment.")
    return value


def find_lakehouse(client: FabricClient, workspace_id: str):
    """Find the supplier analytics lakehouse by display name."""
    return next(
        (
            item
            for item in client.lakehouse.items.list_lakehouses(workspace_id)
            if item.display_name == LAKEHOUSE_NAME
        ),
        None,
    )


def wait_for_sql_endpoint(client: FabricClient, workspace_id: str, lakehouse_id: str):
    """Wait until the lakehouse SQL analytics endpoint is ready."""
    deadline = time.monotonic() + SQL_ENDPOINT_TIMEOUT_SECONDS
    while time.monotonic() < deadline:
        lakehouse = client.lakehouse.items.get_lakehouse(workspace_id, lakehouse_id)
        endpoint = lakehouse.properties.sql_endpoint_properties
        if endpoint.provisioning_status == "Success":
            if not endpoint.id or not endpoint.connection_string:
                raise RuntimeError("The SQL endpoint is ready but has no identity.")
            return endpoint
        if endpoint.provisioning_status == "Failed":
            raise RuntimeError("The lakehouse SQL endpoint failed to provision.")
        time.sleep(5)
    raise TimeoutError("Timed out waiting for the lakehouse SQL endpoint.")


def definition_part(path: Path, replacements: dict[str, str]):
    """Encode one TMDL definition part after resolving runtime markers."""
    relative_path = path.relative_to(DEFINITION_ROOT).as_posix()
    content = path.read_text()
    for marker, value in replacements.items():
        content = content.replace(marker, value)
    if "{{" in content or "}}" in content:
        raise ValueError(f"Unresolved definition marker in {relative_path}.")
    return SemanticModelDefinitionPart(
        path=relative_path,
        payload=base64.b64encode(content.encode()).decode(),
        payload_type="InlineBase64",
    )


def build_definition(sql_endpoint: str, sql_database: str) -> SemanticModelDefinition:
    """Build the source-controlled TMDL definition."""
    files = sorted(path for path in DEFINITION_ROOT.rglob("*") if path.is_file())
    if not files or not (DEFINITION_ROOT / "definition.pbism").exists():
        raise RuntimeError("SupplierSM TMDL definition is incomplete.")
    replacements = {
        "{{SQL_ENDPOINT}}": sql_endpoint,
        "{{SQL_DATABASE}}": sql_database,
    }
    return SemanticModelDefinition(
        format="TMDL",
        parts=[definition_part(path, replacements) for path in files],
    )


def find_semantic_model(client: FabricClient, workspace_id: str):
    """Find SupplierSM by display name."""
    return next(
        (
            item
            for item in client.semanticmodel.items.list_semantic_models(workspace_id)
            if item.display_name == SEMANTIC_MODEL_NAME
        ),
        None,
    )


def main() -> None:
    """Create or update SupplierSM and print its Fabric URL."""
    load_dotenv(ENV_PATH, override=True)
    tenant_id = require_env("FABRIC_TENANT_ID")
    workspace_id = require_env("FABRIC_WORKSPACE_ID")
    credential = AzureDeveloperCliCredential(tenant_id=tenant_id, process_timeout=60)
    try:
        client = FabricClient(credential)
        lakehouse = find_lakehouse(client, workspace_id)
        if lakehouse is None:
            raise RuntimeError(
                f"Lakehouse '{LAKEHOUSE_NAME}' was not found; run create_fabric_lakehouse.py."
            )
        endpoint = wait_for_sql_endpoint(client, workspace_id, lakehouse.id)
        definition = build_definition(endpoint.connection_string, endpoint.id)
        semantic_model = find_semantic_model(client, workspace_id)
        if semantic_model is None:
            print(f"Creating semantic model '{SEMANTIC_MODEL_NAME}'...")
            semantic_model = client.semanticmodel.items.create_semantic_model(
                workspace_id,
                CreateSemanticModelRequest(
                    display_name=SEMANTIC_MODEL_NAME,
                    description="Synthetic supplier performance analytics for Caldova.",
                    definition=definition,
                ),
            )
        else:
            print(f"Updating semantic model '{SEMANTIC_MODEL_NAME}'...")
            client.semanticmodel.items.begin_update_semantic_model_definition(
                workspace_id,
                semantic_model.id,
                UpdateSemanticModelDefinitionRequest(definition=definition),
            ).result
    finally:
        credential.close()

    url = (
        f"{PORTAL_BASE_URL}/groups/{workspace_id}/datasets/{semantic_model.id}/details"
    )
    set_key(ENV_PATH, "FABRIC_SEMANTIC_MODEL_URL", url, quote_mode="never")
    print(f"Semantic model: {SEMANTIC_MODEL_NAME} ({semantic_model.id})")
    print(f"Fabric UI: {url}")


if __name__ == "__main__":
    main()