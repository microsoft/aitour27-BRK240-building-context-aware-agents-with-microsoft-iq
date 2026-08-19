#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Seed all Caldova IQ data: Fabric IQ (supplier analytics), the Fabric IQ ontology,
  and Foundry IQ (the Caldova knowledge base).

.DESCRIPTION
  Reproducible data seeding for the Caldova Supply Autopilot. Runs against the
  resources named in the current azd environment. Web IQ and Work IQ have no data
  to seed (they are connection references only — see seed-connections.ps1).

  Pipeline:

    [1] Fabric IQ — provision the supplier analytics from the official Caldova
        dataset (data/caldova-upstream). Creates the CaldovaSupplierAnalytics
        lakehouse, the SupplierSM semantic model, the Supplier Performance report,
        and the SupplierDataAgent, via the upstream `uv`-based provision scripts.

    [2] Fabric IQ ontology — create the CaldovaSupplierOntology graph structure over
        SupplierSM (create-supplier-ontology.py). NOTE: the ontology graph *build*
        (Publish) is a one-time manual step in the Fabric portal today (preview
        limitation); the script prints the reminder. See docs/supplier-ontology.md.

    [3] Foundry IQ — build the Caldova knowledge base `caldova-supply-kb`:
        - seed-foundryiq.py       -> the policy knowledge source (data/knowledge-base)
        - seed-foundryiq-docs.py  -> procurement / quality / cold-chain document
                                     sources from the upstream corpus, attached to the KB

  Prereqs:
    - `az login` (DefaultAzureCredential); rights on the Search service + Fabric workspace/capacity.
    - `uv` (https://docs.astral.sh/uv/) for the Fabric provision scripts.
    - Python deps for the Foundry IQ scripts: pip install -r infra/scripts/seed-requirements.txt
    - azd env has: TENANT_ID, FABRIC_WORKSPACE_ID, AZURE_AI_SEARCH_SERVICE_ENDPOINT
      (optional: AZURE_OPENAI_ENDPOINT + AZURE_OPENAI_MODEL_DEPLOYMENT for answer synthesis).
#>
param(
    [switch]$SkipFabric,
    [switch]$SkipOntology,
    [switch]$SkipFoundryIQ
)
$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path "$PSScriptRoot/../.."
$upstream = Join-Path $repoRoot "data/caldova-upstream"

function Get-EnvOrThrow([string]$name) {
    $v = [Environment]::GetEnvironmentVariable($name)
    if (-not $v) { throw "Required environment value '$name' is not set (run ``azd env get-values`` or export it)." }
    return $v
}

Push-Location $repoRoot
try {
    if (-not $SkipFabric) {
        Write-Host "=== [1] Fabric IQ - provision supplier analytics (upstream dataset) ===" -ForegroundColor Cyan
        $tenantId    = Get-EnvOrThrow "TENANT_ID"
        $workspaceId = Get-EnvOrThrow "FABRIC_WORKSPACE_ID"
        # The upstream scripts read a root .env (FABRIC_TENANT_ID + FABRIC_WORKSPACE_ID).
        "FABRIC_TENANT_ID=$tenantId`nFABRIC_WORKSPACE_ID=$workspaceId" |
            Set-Content -Path (Join-Path $upstream ".env") -Encoding utf8 -NoNewline
        Push-Location $upstream
        try {
            uv sync --locked
            uv run python provision/fabric/create_fabric_lakehouse.py
            uv run python provision/fabric/create_fabric_semantic_model.py
            uv run python provision/fabric/create_fabric_reports.py
            uv run python provision/fabric/create_fabric_data_agent.py
        }
        finally { Pop-Location }
    }

    if (-not $SkipOntology) {
        Write-Host "=== [2] Fabric IQ - create the supplier ontology structure ===" -ForegroundColor Cyan
        python infra/scripts/create-supplier-ontology.py
        if ($LASTEXITCODE -ne 0) { throw "create-supplier-ontology.py failed ($LASTEXITCODE)." }
        Write-Host "  Ontology structure created. One manual step remains (preview): open" -ForegroundColor Yellow
        Write-Host "  CaldovaSupplierOntology in the Fabric portal, Publish it, then add it as a" -ForegroundColor Yellow
        Write-Host "  SupplierDataAgent data source. See docs/supplier-ontology.md." -ForegroundColor Yellow
    }

    if (-not $SkipFoundryIQ) {
        Write-Host "=== [3] Foundry IQ - build the Caldova knowledge base ===" -ForegroundColor Cyan
        [void](Get-EnvOrThrow "AZURE_AI_SEARCH_SERVICE_ENDPOINT")
        python infra/scripts/seed-foundryiq.py
        if ($LASTEXITCODE -ne 0) { throw "seed-foundryiq.py failed ($LASTEXITCODE)." }
        python infra/scripts/seed-foundryiq-docs.py --attach-to-kb
        if ($LASTEXITCODE -ne 0) { throw "seed-foundryiq-docs.py failed ($LASTEXITCODE)." }
    }

    Write-Host ""
    Write-Host "Seeding complete. Next: register the four IQ Foundry project connections" -ForegroundColor Green
    Write-Host "(seed-and-connect.ps1 chains this script with seed-connections.ps1)." -ForegroundColor Green
    Write-Host "See infra/README.md and docs/setup.md."
}
finally {
    Pop-Location
}
