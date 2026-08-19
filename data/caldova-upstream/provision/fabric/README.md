# Fabric provisioning

These scripts create or update Caldova supplier analytics in an existing
Microsoft Fabric workspace. Run all commands from the repository root.

## Prerequisites

- Python 3.12 or later
- [uv](https://docs.astral.sh/uv/)
- [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- A Fabric workspace where your account can create and update items
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
```

The table data is derived from:

- `sample-data/json/waypoint-supplier-invoices.json`
- `sample-data/json/supplier-kpi-profiles.json`

## Deploy

Run the scripts in dependency order:

```bash
uv run python provision/fabric/create_fabric_lakehouse.py
uv run python provision/fabric/create_fabric_semantic_model.py
uv run python provision/fabric/create_fabric_reports.py
uv run python provision/fabric/create_fabric_data_agent.py
```

The scripts create or update these stable artifacts:

| Script | Fabric artifact |
| --- | --- |
| `create_fabric_lakehouse.py` | `CaldovaSupplierAnalytics` lakehouse and seven Delta tables |
| `create_fabric_semantic_model.py` | `SupplierSM` semantic model |
| `create_fabric_reports.py` | `Supplier Performance` report |
| `create_fabric_data_agent.py` | `SupplierDataAgent` Data Agent |

The lakehouse script reuses the existing named lakehouse and overwrites its
supplier tables. The semantic-model and report scripts similarly update existing
named items. The Data Agent stage configures and publishes the named agent.

The Data Agent is optional. To record an explicitly partial deployment without
creating or updating it, run:

```bash
uv run python provision/fabric/create_fabric_data_agent.py --skip
```

## Outputs

Successful lakehouse, semantic-model, and report deployments print their Fabric
URLs and write these values to the root `.env` file:

```dotenv
FABRIC_LAKEHOUSE_URL=...
FABRIC_SEMANTIC_MODEL_URL=...
FABRIC_REPORT_URL=...
```

The Data Agent script prints its MCP endpoint after publishing.

The semantic model and report definitions are stored under
`sample-data/fabric/Supply Chain Operations/`.
