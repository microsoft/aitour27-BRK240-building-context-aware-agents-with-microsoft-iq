#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Build the standalone Foundry-agent container image with ACR Build (cloud build).

.DESCRIPTION
  Independent of the autopilot image. Produces `caldova-supply-hosted-agent:latest` in
  the same ACR the autopilot uses (so no extra registry is needed). The image is a
  tiny Responses-protocol server — no build args / no baked identity.

  Required env (read from the azd environment by deploy.ps1):
    AZURE_CONTAINER_REGISTRY_ENDPOINT   e.g. myacr.azurecr.io
#>
$ErrorActionPreference = "Stop"

Set-Location "$PSScriptRoot/../../src"

# Clean caches so they are not copied into the build context.
Get-ChildItem -Path . -Filter "__pycache__" -Recurse -Force -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

$acrLoginServer = $env:AZURE_CONTAINER_REGISTRY_ENDPOINT
if (-not $acrLoginServer) { throw "AZURE_CONTAINER_REGISTRY_ENDPOINT is required" }
$registryName = $acrLoginServer.Split(".")[0]
$imageName = "caldova-supply-hosted-agent:latest"

Write-Host "Building $imageName using ACR Build in registry: $registryName"

az acr build `
    --registry $registryName `
    --image $imageName `
    --file "./Dockerfile" `
    .

if ($LASTEXITCODE -ne 0) { throw "ACR build failed with exit code $LASTEXITCODE" }
Write-Host "Image built and pushed: $acrLoginServer/$imageName"
