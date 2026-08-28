"""Create or update the Caldova Supplier Performance Power BI report."""

import base64
import os
import warnings
from pathlib import Path

from azure.identity import AzureCliCredential as AzureDeveloperCliCredential  # az is reliable inside the azd hook (azd auth token can time out there)
from dotenv import load_dotenv, set_key

warnings.filterwarnings("ignore", category=SyntaxWarning, module=r"microsoft_fabric_api\..*")

from microsoft_fabric_api import FabricClient  # noqa: E402
from microsoft_fabric_api.generated.report.models import (  # noqa: E402
    CreateReportRequest,
    ReportDefinition,
    ReportDefinitionPart,
    UpdateReportDefinitionRequest,
)

REPO_ROOT = Path(__file__).parents[2]
ENV_PATH = REPO_ROOT / ".env"
DEFINITION_ROOT = (
    REPO_ROOT
    / "sample-data/fabric/Supply Chain Operations/Supplier Performance (Report)"
)
SEMANTIC_MODEL_NAME = "SupplierSM"
REPORT_NAME = "Supplier Performance"
PORTAL_BASE_URL = "https://msit.powerbi.com"


def require_env(name: str) -> str:
    """Return a required environment setting."""
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"{name} is required for Fabric deployment.")
    return value


def definition_part(path: Path, semantic_model_id: str) -> ReportDefinitionPart:
    """Encode one PBIR part after binding it to SupplierSM."""
    relative_path = path.relative_to(DEFINITION_ROOT).as_posix()
    if path.suffix in {".json", ".pbir"} or path.name == ".platform":
        payload = path.read_text().replace("{{SEMANTIC_MODEL_ID}}", semantic_model_id).encode()
        if b"{{" in payload or b"}}" in payload:
            raise ValueError(f"Unresolved definition marker in {relative_path}.")
    else:
        payload = path.read_bytes()
    return ReportDefinitionPart(
        path=relative_path,
        payload=base64.b64encode(payload).decode(),
        payload_type="InlineBase64",
    )


def build_definition(semantic_model_id: str) -> ReportDefinition:
    """Build the source-controlled two-page PBIR definition."""
    files = sorted(path for path in DEFINITION_ROOT.rglob("*") if path.is_file())
    if not files or not (DEFINITION_ROOT / "definition.pbir").exists():
        raise RuntimeError("Supplier Performance PBIR definition is incomplete.")
    return ReportDefinition(
        format="PBIR",
        parts=[definition_part(path, semantic_model_id) for path in files],
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


def find_report(client: FabricClient, workspace_id: str):
    """Find the consolidated report by display name."""
    return next(
        (
            item
            for item in client.report.items.list_reports(workspace_id)
            if item.display_name == REPORT_NAME
        ),
        None,
    )


def main() -> None:
    """Create or update the report and print its Fabric URL."""
    load_dotenv(ENV_PATH, override=True)
    tenant_id = require_env("FABRIC_TENANT_ID")
    workspace_id = require_env("FABRIC_WORKSPACE_ID")
    credential = AzureDeveloperCliCredential(tenant_id=tenant_id)
    try:
        client = FabricClient(credential)
        semantic_model = find_semantic_model(client, workspace_id)
        if semantic_model is None:
            raise RuntimeError(
                f"Semantic model '{SEMANTIC_MODEL_NAME}' was not found; deploy it first."
            )
        definition = build_definition(semantic_model.id)
        report = find_report(client, workspace_id)
        if report is None:
            print(f"Creating report '{REPORT_NAME}'...")
            report = client.report.items.create_report(
                workspace_id,
                CreateReportRequest(
                    display_name=REPORT_NAME,
                    description="Supplier performance, quality, trends, and geography.",
                    definition=definition,
                ),
            )
        else:
            print(f"Updating report '{REPORT_NAME}'...")
            client.report.items.begin_update_report_definition(
                workspace_id,
                report.id,
                UpdateReportDefinitionRequest(definition=definition),
            ).result
    finally:
        credential.close()

    url = f"{PORTAL_BASE_URL}/groups/{workspace_id}/reports/{report.id}"
    set_key(ENV_PATH, "FABRIC_REPORT_URL", url, quote_mode="never")
    print(f"Report: {REPORT_NAME} ({report.id})")
    print(f"Fabric UI: {url}")


if __name__ == "__main__":
    main()