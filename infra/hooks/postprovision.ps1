#!/usr/bin/env pwsh
# =================================================================================================
# azd postprovision hook — the ONE command chain.
#
# After `azd up` provisions the Azure resources (infra/main.bicep: Foundry account + project +
# Container Registry + Azure AI Search + optional Fabric capacity), this hook builds the rest of
# the Caldova demo end to end, so `azd up` gives you the full thing:
#
#   1. Fabric data      — lakehouse, ontology (+ graph refresh), semantic model, report, Data Agent
#   2. IQ connections   — Foundry IQ (KB in the provisioned Search), Fabric, Work IQ, Web IQ
#   3. Foundry Hosted Agent (demos 1–4) — the caldova-supply-tools toolbox + the hosted agent
#   4. Agent 365 autopilot (demo 5)     — build image + create the autopilot version
#   5. Demo mailboxes   — seed the two escalation emails
#
# Modeled on microsoft/Build26-LAB532 and the iqdeepdive autopilot (azd up + postprovision).
#
# STATUS: this orchestrator reuses the repo's individually-validated scripts, but the full
# end-to-end `azd up` has not yet been validated on a clean subscription. Run it once end to end
# and adjust any step that needs it (the Fabric workspace bootstrap and email seeding are the most
# environment-dependent). Each step is guarded so a partial/opt-in run is possible.
# =================================================================================================
$ErrorActionPreference = "Stop"
# Fail fast when a native command (python/az/uv) exits non-zero, so a broken step aborts the
# chain instead of silently continuing (PowerShell does not do this by default).
$PSNativeCommandUseErrorActionPreference = $true
$repoRoot = Resolve-Path "$PSScriptRoot/../.."
Write-Host "=== azd postprovision — building the Caldova demo ===" -ForegroundColor Cyan
Write-Host "Search endpoint : $env:AZURE_AI_SEARCH_SERVICE_ENDPOINT"
Write-Host "Fabric capacity : $(if ($env:FABRIC_CAPACITY_ID) { $env:FABRIC_CAPACITY_NAME } else { '(none — using existing FABRIC_WORKSPACE_ID)' })"

# --- 1. Fabric workspace ------------------------------------------------------------------------
# A Fabric *capacity* is provisioned by Bicep, but a *workspace* is not an ARM resource. Create it
# here (via the Fabric REST API) unless FABRIC_WORKSPACE_ID already points to an existing workspace.
# The Fabric *data* is provisioned by seed-and-connect.ps1 in step 2 (the canonical seeding pipeline).
if (-not $env:FABRIC_WORKSPACE_ID) {
    Write-Host "`n--- [1/5] Creating a Fabric workspace ---" -ForegroundColor Cyan
    $env:FABRIC_WORKSPACE_ID = & "$repoRoot/infra/scripts/create-fabric-workspace.ps1" -SetAzdEnv
} else {
    Write-Host "`n--- [1/5] Using existing Fabric workspace $env:FABRIC_WORKSPACE_ID ---" -ForegroundColor Cyan
}

# --- 2. Seed Fabric data + Foundry IQ KB, then create the four IQ connections --------------------
Write-Host "`n--- [2/5] Seeding Fabric data, Foundry IQ KB, and the four IQ connections ---" -ForegroundColor Cyan
$seedArgs = @{ SetAzdEnv = $true }
if ($env:WEB_IQ_API_KEY) { $seedArgs.WebIqApiKey = $env:WEB_IQ_API_KEY }
$conn = & "$repoRoot/infra/scripts/seed-and-connect.ps1" @seedArgs
if ($conn.FabricConnectionId) { $env:FABRIC_CONNECTION_ID = $conn.FabricConnectionId }
if ($conn.FoundryIqConnectionId) { $env:FOUNDRY_IQ_CONNECTION_ID = $conn.FoundryIqConnectionId }
if ($conn.FoundryIqMcpUrl) { $env:FOUNDRY_IQ_MCP_URL = $conn.FoundryIqMcpUrl }
if ($conn.WorkIqConnectionId) { $env:WORK_IQ_CONNECTION_ID = $conn.WorkIqConnectionId }
if ($conn.WebIqConnectionId) { $env:WEB_IQ_CONNECTION_ID = $conn.WebIqConnectionId }

# --- 3. Foundry Hosted Agent (demos 1–4) --------------------------------------------------------
Write-Host "`n--- [3/5] Toolbox + Foundry Hosted Agent ---" -ForegroundColor Cyan
& "$repoRoot/src/foundry-hosted-agent/infra/scripts/create-toolbox.ps1"
& "$repoRoot/src/foundry-hosted-agent/infra/scripts/deploy.ps1"

# --- 4. Agent 365 autopilot (demo 5) ------------------------------------------------------------
# Builds the image + creates the autopilot version (auto-create blueprint, two passes). The
# Agent 365 registration/publish (admin-gated) still runs afterwards via infra/a365/publish-autopilot.ps1.
Write-Host "`n--- [4/5] Agent 365 autopilot (build + version-create) ---" -ForegroundColor Cyan
& "$repoRoot/infra/scripts/post-provision.ps1"

# --- 5. Seed the demo mailboxes -----------------------------------------------------------------
Write-Host "`n--- [5/5] Seeding demo mailboxes ---" -ForegroundColor Cyan
& "$PSScriptRoot/seed-emails.ps1"

Write-Host "`n=== azd up complete ===" -ForegroundColor Green
Write-Host "Next (admin-gated): register the autopilot in Agent 365 -> ./infra/a365/publish-autopilot.ps1"
Write-Host "Then hire an instance in Teams. See delivery-resources/README.md."
