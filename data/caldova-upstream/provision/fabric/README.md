# Fabric provisioning

These scripts create or update Caldova supplier analytics in an existing
Microsoft Fabric workspace. Run all commands from the repository root.

## Prerequisites

- Python 3.12 or later
- [uv](https://docs.astral.sh/uv/)
- [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- A Fabric workspace where your account can create and update items
- The Fabric IQ Ontology preview enabled for the tenant
- Fabric capacity that supports any optional Data Agent deployment

Install the Python dependencies:

```bash
uv sync --locked
```

## Configure

Create a root `.env` file with the target tenant and workspace IDs:

```dotenv
FABRIC_TENANT_ID=<tenant-id>
FABRIC_WORKSPACE_ID=<workspace-id>
```

The `.env` file is ignored by Git. The IDs are available from the Fabric
workspace URL and your Microsoft Entra tenant details.

## Authenticate

The scripts use `AzureDeveloperCliCredential`. Authenticate Azure Developer CLI
for the same tenant before running them. On shared machines, use an isolated
configuration directory so authentication state is not mixed with other work:

```bash
export AZD_CONFIG_DIR="$HOME/.azd-caldova"
azd auth login --tenant-id <tenant-id> --use-device-code=false
```

Keep `AZD_CONFIG_DIR` set in the shell used to run the provisioning scripts.

## Validate locally

Build and validate all lakehouse tables without contacting Fabric:

```bash
uv run python provision/fabric/create_fabric_lakehouse.py --validate-only
uv run python provision/fabric/create_fabric_ontology.py --validate-only
```

The table data is derived from:

- `sample-data/json/waypoint-supplier-invoices.json`
- `sample-data/json/suppliers.json`
- `sample-data/json/supplier-kpi-profiles.json`
- `sample-data/json/medicinal-product-ontology.json`

The canonical registry contains 18 suppliers. The invoice corpus contains activity
for 15 of them; a supplier does not need an invoice to participate in analytics or
the ontology.

## Deploy

Run the scripts in dependency order:

```bash
uv run python provision/fabric/create_fabric_lakehouse.py
uv run python provision/fabric/create_fabric_ontology.py
uv run python provision/fabric/create_fabric_semantic_model.py
uv run python provision/fabric/create_fabric_reports.py
uv run python provision/fabric/create_fabric_data_agent.py
```

The scripts create or update these stable artifacts:

| Script | Fabric artifact |
| --- | --- |
| `create_fabric_lakehouse.py` | `CaldovaSupplierAnalytics` lakehouse and 14 Delta tables |
| `create_fabric_ontology.py` | `CaldovaMedicinalProductOntology` Fabric IQ ontology |
| `create_fabric_semantic_model.py` | `SupplierSM` semantic model |
| `create_fabric_reports.py` | `Supplier Performance` report |
| `create_fabric_data_agent.py` | `SupplierDataAgent` Data Agent |

The lakehouse script reuses the existing named lakehouse and overwrites its
supplier tables. The semantic-model and report scripts similarly update existing
named items. The Data Agent stage attaches `SupplierSM` and
`CaldovaMedicinalProductOntology`, then configures and publishes the named agent.

The Data Agent is optional. To record an explicitly partial deployment without
creating or updating it, run:

```bash
uv run python provision/fabric/create_fabric_data_agent.py --skip
```

## Outputs

Successful lakehouse, ontology, semantic-model, and report deployments print their
Fabric URLs and write these values to the root `.env` file:

```dotenv
FABRIC_LAKEHOUSE_URL=...
FABRIC_ONTOLOGY_ID=...
FABRIC_ONTOLOGY_UI_URL=...
FABRIC_ONTOLOGY_MCP_URL=...
FABRIC_SEMANTIC_MODEL_URL=...
FABRIC_REPORT_URL=...
FABRIC_DATA_AGENT_MCP_URL=...
FABRIC_DATA_AGENT_UI_URL=...
```

The Data Agent script also prints its Fabric UI and MCP URLs after publishing.

The semantic model and report definitions are stored under
`sample-data/fabric/Supply Chain Operations/`.
