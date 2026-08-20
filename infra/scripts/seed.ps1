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

    [1] Fabric IQ — provision the whole Fabric stack from the official Caldova
        dataset (data/caldova-upstream) using the upstream `uv`-based provision
        scripts, in their documented dependency order:

          create_fabric_lakehouse.py       -> CaldovaSupplierAnalytics (14 Delta tables)
          create_fabric_ontology.py        -> CaldovaMedicinalProductOntology
          ../../infra/scripts/refresh-ontology-graph.py
                                           -> builds the ontology graph (see note below)
          create_fabric_semantic_model.py  -> SupplierSM
          create_fabric_reports.py         -> Supplier Performance
          create_fabric_data_agent.py      -> SupplierDataAgent

        NOTE: creating the ontology materializes an EMPTY graph model. Until it is
        refreshed, the Data Agent answers ontology questions with "the graph model
        required to answer this query is currently unavailable". The upstream scripts
        do not trigger that refresh, so this repo runs refresh-ontology-graph.py as a
        post-step. It is a normal Fabric job — there is no portal step.

        The Data Agent stage attaches BOTH SupplierSM and the ontology, so it can
        answer supplier analytics (DAX), ontology traversal (GQL), and questions
        that combine the two by joining Manufacturer.manufacturerId to
        DimSupplier.SupplierID. The ontology must run before the Data Agent, which
        requires FABRIC_ONTOLOGY_ID from the upstream .env.

    [2] Foundry IQ — build the Caldova knowledge base `caldova-supply-kb`:
        - seed-foundryiq.py       -> the policy knowledge source (data/knowledge-base)
        - seed-foundryiq-docs.py  -> procurement / quality / cold-chain document
                                     sources from the upstream corpus, attached to the KB

  Prereqs:
    - `az login` (DefaultAzureCredential) for the Foundry IQ scripts; rights on the Search service.
    - `azd auth login` for the Fabric provision scripts (they use AzureDeveloperCliCredential),
      plus rights to create/update items in the Fabric workspace and capacity.
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

function Set-UpstreamEnvValue([string]$path, [hashtable]$values) {
    # Merge keys into the upstream .env rather than overwriting it: the provision
    # scripts write FABRIC_ONTOLOGY_ID / FABRIC_*_URL back to this same file, and the
    # Data Agent stage reads FABRIC_ONTOLOGY_ID from it.
    $lines = @()
    if (Test-Path $path) { $lines = @(Get-Content $path) }
    foreach ($key in $values.Keys) {
        $entry = "$key=$($values[$key])"
        $match = $lines | Select-String -Pattern "^\s*$key\s*=" | Select-Object -First 1
        if ($match) { $lines[$match.LineNumber - 1] = $entry } else { $lines += $entry }
    }
    Set-Content -Path $path -Value $lines -Encoding utf8
}

Push-Location $repoRoot
try {
    if (-not $SkipFabric) {
        Write-Host "=== [1] Fabric IQ - provision the Caldova Fabric stack (upstream dataset) ===" -ForegroundColor Cyan
        $tenantId    = Get-EnvOrThrow "TENANT_ID"
        $workspaceId = Get-EnvOrThrow "FABRIC_WORKSPACE_ID"
        # The upstream scripts read a root .env (FABRIC_TENANT_ID + FABRIC_WORKSPACE_ID)
        # and write their own outputs back into it.
        Set-UpstreamEnvValue (Join-Path $upstream ".env") @{
            FABRIC_TENANT_ID    = $tenantId
            FABRIC_WORKSPACE_ID = $workspaceId
        }
        Push-Location $upstream
        try {
            uv sync --locked
            if ($LASTEXITCODE -ne 0) { throw "uv sync failed ($LASTEXITCODE)." }

            # Upstream dependency order (data/caldova-upstream/provision/fabric/README.md).
            # The ontology must precede the Data Agent, which requires FABRIC_ONTOLOGY_ID.
            $steps = @(
                @{ Script = "provision/fabric/create_fabric_lakehouse.py";      Label = "CaldovaSupplierAnalytics lakehouse (14 Delta tables)" }
                @{ Script = "provision/fabric/create_fabric_ontology.py";       Label = "CaldovaMedicinalProductOntology"; Ontology = $true }
                @{ Script = "../../infra/scripts/refresh-ontology-graph.py";    Label = "Ontology graph build (refreshGraph)"; Ontology = $true }
                @{ Script = "provision/fabric/create_fabric_semantic_model.py"; Label = "SupplierSM semantic model" }
                @{ Script = "provision/fabric/create_fabric_reports.py";        Label = "Supplier Performance report" }
                @{ Script = "provision/fabric/create_fabric_data_agent.py";     Label = "SupplierDataAgent (attaches SupplierSM + ontology)" }
            )
            foreach ($step in $steps) {
                if ($step.Ontology -and $SkipOntology) {
                    Write-Host "  -- skipping $($step.Label) (-SkipOntology)" -ForegroundColor Yellow
                    Write-Host "     NOTE: the Data Agent stage still needs FABRIC_ONTOLOGY_ID from a previous run." -ForegroundColor Yellow
                    continue
                }
                Write-Host "  -> $($step.Label)" -ForegroundColor Cyan
                uv run python $step.Script
                if ($LASTEXITCODE -ne 0) { throw "$($step.Script) failed ($LASTEXITCODE)." }
            }
        }
        finally { Pop-Location }
    }

    if (-not $SkipFoundryIQ) {
        Write-Host "=== [2] Foundry IQ - build the Caldova knowledge base ===" -ForegroundColor Cyan
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
