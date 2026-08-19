"""Seed Foundry IQ: create the Caldova supply-policy knowledge base in Azure AI Search.

Pure REST implementation (no preview-SDK model classes, which change across versions).
Mirrors a known-good Foundry IQ knowledge-base schema. Creates or updates:

  1. A search **index** over the Caldova policy markdown in ``data/knowledge-base``.
  2. A **knowledge source** (searchIndex kind) over that index.
  3. A **knowledge base** (agentic retrieval) named ``caldova-supply-kb``. If an Azure
     OpenAI model is supplied it uses ``answerSynthesis``; otherwise ``extractiveData``.

Auth uses ``DefaultAzureCredential`` (``az login``) for the Search data plane
(``https://search.azure.com/.default``). The caller needs Search Service Contributor +
Search Index Data Contributor on the Search service.

Environment:
  AZURE_AI_SEARCH_SERVICE_ENDPOINT   https://<service>.search.windows.net   (required)
  FOUNDRYIQ_KB_NAME                  KB name (default caldova-supply-kb)
  FOUNDRYIQ_INDEX_NAME               index name (default caldova-supply-policies)
  KB_API_VERSION                     Search api-version (default 2026-05-01-preview)
  # Optional answer-synthesis model (recommended: a NON-reasoning model such as gpt-4.1;
  # reasoning models can fail agentic retrieval with BadGateway):
  AZURE_OPENAI_ENDPOINT              e.g. https://<res>.openai.azure.com
  AZURE_OPENAI_MODEL_DEPLOYMENT      e.g. gpt-4.1
  AZURE_OPENAI_API_KEY               key for the AOAI resource

Usage:  python infra/scripts/seed-foundryiq.py
"""

from __future__ import annotations

import os
import re
from pathlib import Path

import httpx
from azure.identity import DefaultAzureCredential

REPO_ROOT = Path(__file__).resolve().parents[2]
KB_DOCS_DIR = REPO_ROOT / "data" / "knowledge-base"

SEARCH_ENDPOINT = os.environ.get("AZURE_AI_SEARCH_SERVICE_ENDPOINT", "").rstrip("/")
KB_NAME = os.environ.get("FOUNDRYIQ_KB_NAME", "caldova-supply-kb")
INDEX_NAME = os.environ.get("FOUNDRYIQ_INDEX_NAME", "caldova-supply-policies")
KS_NAME = f"{INDEX_NAME}-ks"
API_VERSION = os.environ.get("KB_API_VERSION", "2026-05-01-preview")

AOAI_ENDPOINT = os.environ.get("AZURE_OPENAI_ENDPOINT", "").rstrip("/")
AOAI_MODEL = os.environ.get("AZURE_OPENAI_MODEL_DEPLOYMENT", "")
AOAI_KEY = os.environ.get("AZURE_OPENAI_API_KEY", "")


def _chunk_markdown(path: Path) -> list[dict[str, str]]:
    """Split a policy markdown file into section-level documents for indexing."""
    text = path.read_text(encoding="utf-8")
    title = path.stem
    parts = re.split(r"^##\s+", text, flags=re.MULTILINE)
    docs: list[dict[str, str]] = []
    for i, part in enumerate(parts):
        content = part.strip()
        if not content:
            continue
        heading = content.splitlines()[0].strip() if i > 0 else title
        docs.append(
            {
                "id": f"{path.stem}-{i}",
                "title": f"{title} - {heading}",
                "source": path.name,
                "content": content,
            }
        )
    return docs


def _put(client: httpx.Client, path: str, body: dict) -> None:
    url = f"{SEARCH_ENDPOINT}/{path}?api-version={API_VERSION}"
    r = client.put(url, json=body)
    if r.status_code >= 400:
        raise SystemExit(f"PUT {path} failed {r.status_code}: {r.text}")


def main() -> None:
    if not SEARCH_ENDPOINT:
        raise SystemExit("AZURE_AI_SEARCH_SERVICE_ENDPOINT is required.")
    if not KB_DOCS_DIR.exists():
        raise SystemExit(f"Knowledge-base docs folder not found: {KB_DOCS_DIR}")

    docs: list[dict[str, str]] = []
    for md in sorted(KB_DOCS_DIR.glob("*.md")):
        docs.extend(_chunk_markdown(md))
    print(f"Prepared {len(docs)} policy chunks from {KB_DOCS_DIR}")

    credential = DefaultAzureCredential()
    token = credential.get_token("https://search.azure.com/.default").token
    with httpx.Client(timeout=120, headers={"Authorization": f"Bearer {token}"}) as client:
        # 1) Index (with a "default" semantic config the knowledge source references)
        index_body = {
            "name": INDEX_NAME,
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
        _put(client, f"indexes/{INDEX_NAME}", index_body)
        print(f"Created/updated index: {INDEX_NAME}")

        # 2) Upload documents
        r = client.post(
            f"{SEARCH_ENDPOINT}/indexes/{INDEX_NAME}/docs/index?api-version={API_VERSION}",
            json={"value": [{"@search.action": "mergeOrUpload", **d} for d in docs]},
        )
        if r.status_code >= 400:
            raise SystemExit(f"Doc upload failed {r.status_code}: {r.text}")
        print(f"Uploaded {len(docs)} documents to {INDEX_NAME}")

        # 3) Knowledge source (searchIndex kind)
        ks_body = {
            "name": KS_NAME,
            "kind": "searchIndex",
            "description": "Caldova supply, returns, and cold-chain policy documents.",
            "searchIndexParameters": {
                "searchIndexName": INDEX_NAME,
                "semanticConfigurationName": "default",
                "sourceDataFields": [{"name": "title"}, {"name": "source"}],
                "searchFields": [{"name": "title"}, {"name": "content"}],
            },
        }
        _put(client, f"knowledgeSources/{KS_NAME}", ks_body)
        print(f"Created/updated knowledge source: {KS_NAME}")

        # 4) Knowledge base
        kb_body: dict = {
            "name": KB_NAME,
            "description": "Caldova supply-assurance knowledge base: returns, replacement, "
            "credit, and cold-chain (GDP) policy.",
            "knowledgeSources": [{"name": KS_NAME}],
            "retrievalReasoningEffort": {"kind": "low"},
        }
        if AOAI_ENDPOINT and AOAI_MODEL and AOAI_KEY:
            kb_body["outputMode"] = "answerSynthesis"
            kb_body["models"] = [
                {
                    "kind": "azureOpenAI",
                    "azureOpenAIParameters": {
                        "resourceUri": AOAI_ENDPOINT,
                        "deploymentId": AOAI_MODEL,
                        "modelName": AOAI_MODEL,
                        "apiKey": AOAI_KEY,
                    },
                }
            ]
        else:
            kb_body["outputMode"] = "extractiveData"
        _put(client, f"knowledgeBases/{KB_NAME}", kb_body)
        print(f"Created/updated knowledge base: {KB_NAME} ({kb_body['outputMode']})")

    mcp_url = f"{SEARCH_ENDPOINT}/knowledgebases/{KB_NAME}/mcp?api-version={API_VERSION}"
    print("\nFoundry IQ seeded. Wire these into the agent env:")
    print(f"  FOUNDRYIQ_CONNECTION_ID = {KB_NAME}")
    print(f"  FOUNDRYIQ_MCP_URL       = {mcp_url}")
    print(
        f"\nRegister a Foundry project connection named '{KB_NAME}' pointing at the MCP URL "
        "above (ProjectManagedIdentity auth). See ../README.md."
    )


if __name__ == "__main__":
    main()
