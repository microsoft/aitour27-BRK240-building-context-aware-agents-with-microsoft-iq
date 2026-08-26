# Build Docker image using Azure Container Registry (ACR) Build
# This script uses ACR Tasks to build the image in the cloud instead of locally

Set-Location "$($PSScriptRoot)/../../src/autopilot"

Remove-Item "./__pycache__" -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem -Path . -Filter "__pycache__" -Recurse -Force -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "./.vs" -Recurse -Force -ErrorAction SilentlyContinue

$authorityEndpoint = "https://login.microsoftonline.com/$($env:TENANT_ID)"
$azureOpenAIEndpoint = "https://$($env:ACCOUNT_NAME).openai.azure.com/"

# Blueprint + instance client ids are only known AFTER the first version-create
# (auto-create blueprint model). Pass 1 builds with a placeholder; post-provision.ps1
# sets AGENT_BLUEPRINT_CLIENT_ID / AGENT_INSTANCE_CLIENT_ID and rebuilds for pass 2.
$placeholder = "00000000-0000-0000-0000-000000000000"
$blueprintClientId = if ($env:AGENT_BLUEPRINT_CLIENT_ID) { $env:AGENT_BLUEPRINT_CLIENT_ID } else { $placeholder }
$instanceClientId  = if ($env:AGENT_INSTANCE_CLIENT_ID)  { $env:AGENT_INSTANCE_CLIENT_ID }  else { $placeholder }

$acrLoginServer = $env:AZURE_CONTAINER_REGISTRY_ENDPOINT

# split the login server to get the registry name
$registryName = $acrLoginServer.Split(".")[0]

$imageName = "caldova-supply-autopilot:latest"

Write-Host "Building image using ACR Build in registry: $registryName (blueprint=$blueprintClientId)"

# Build image using ACR Build (builds in the cloud). `--progress-bar off --no-color` avoids the
# cp1252 UnicodeEncodeError az hits on Windows when rendering pip progress bars.
az acr build `
    --registry $registryName `
    --image $imageName `
    --file "./foundry-infra/Dockerfile" `
    --build-arg BLUEPRINT_CLIENT_ID=$blueprintClientId `
    --build-arg INSTANCE_CLIENT_ID=$instanceClientId `
    --build-arg AUTHORITY_ENDPOINT=$authorityEndpoint `
    --build-arg TENANT_ID=$env:TENANT_ID `
    --build-arg AZURE_OPENAI_ENDPOINT=$azureOpenAIEndpoint `
    --build-arg MODEL_DEPLOYMENT=$env:MODEL_NAME `
    .

if ($LASTEXITCODE -ne 0) {
    throw "ACR build failed with exit code $LASTEXITCODE"
}

Write-Host "Image built and pushed successfully: $acrLoginServer/$imageName"
