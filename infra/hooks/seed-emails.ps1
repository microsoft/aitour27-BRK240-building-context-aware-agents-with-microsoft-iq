#!/usr/bin/env pwsh
# =================================================================================================
# Seed the two Caldova escalation emails used by the Work IQ demos.
#
#   * demo 4 (Playground, on-behalf-of you): Priya Nair — SHP-9021 (Brightline Labs) -> YOUR mailbox
#   * demo 5 (Teams, the autopilot): Maria Garcia — SHP-1234 (Alvexa) -> the AGENT-USER mailbox
#     (only exists after the autopilot is hired in Teams — seed it then)
#
# Tries to send via Microsoft Graph using your az CLI token. If that token lacks Mail.Send
# (common), it prints the emails so you can send them manually. Modeled on LAB532 seed-emails.ps1.
# =================================================================================================
param(
    [string]$YourMailbox = "",         # defaults to the signed-in az user
    [string]$AgentMailbox = ""         # the agent-user UPN, once hired (optional)
)
$ErrorActionPreference = "Continue"

$priya = @{
    subject = "URGENT - Caldova cold-chain excursion SHP-9021 (Brightline Labs) - replacement + credit needed"
    body    = "Hi,`n`nFlagging an urgent cold-chain temperature excursion on shipment SHP-9021 from Brightline Labs (API supplier). The data logger shows a 6-hour excursion above 8C in transit. Per the Caldova cold-chain policy this looks eligible for free replacement + credit.`n`nCan you confirm disposition and OTIF impact for Brightline Labs? The customer is waiting.`n`nThanks,`nPriya Nair`nCaldova Supply Quality"
}
$maria = @{
    subject = "URGENT - Temperature excursion on SHP-1234 (Alvexa), need replacement + credit"
    body    = "Hi,`n`nWe've had a cold-chain temperature excursion on shipment SHP-1234 (Alvexa). Please review and confirm replacement + credit under the Caldova cold-chain policy.`n`nThanks,`nMaria Garcia"
}

function Send-Seed($toAddress, $mail) {
    if (-not $toAddress) { return $false }
    $token = az account get-access-token --resource https://graph.microsoft.com --query accessToken -o tsv 2>$null
    if (-not $token) { return $false }
    $payload = @{
        message = @{
            subject = $mail.subject
            importance = "high"
            body = @{ contentType = "Text"; content = $mail.body }
            toRecipients = @(@{ emailAddress = @{ address = $toAddress } })
        }
        saveToSentItems = $true
    } | ConvertTo-Json -Depth 8
    $tmp = New-TemporaryFile
    $payload | Out-File $tmp -Encoding utf8
    az rest --method post --url "https://graph.microsoft.com/v1.0/users/$toAddress/sendMail" `
        --headers "Content-Type=application/json" --body "@$tmp" 2>$null | Out-Null
    $ok = ($LASTEXITCODE -eq 0)
    Remove-Item $tmp -ErrorAction SilentlyContinue
    return $ok
}

# Resolve your mailbox from the signed-in user if not supplied.
if (-not $YourMailbox) {
    $YourMailbox = az ad signed-in-user show --query "userPrincipalName" -o tsv 2>$null
}

$yourOk = Send-Seed $YourMailbox $priya
$agentOk = $false
if ($AgentMailbox) { $agentOk = Send-Seed $AgentMailbox $maria }

if ($yourOk) {
    Write-Host "Seeded YOUR mailbox ($YourMailbox): Priya Nair / SHP-9021." -ForegroundColor Green
} else {
    Write-Host "Could not auto-send to your mailbox (token likely lacks Mail.Send). Send this to yourself:" -ForegroundColor Yellow
    Write-Host "  To      : $YourMailbox"
    Write-Host "  Subject : $($priya.subject)"
    Write-Host "  Body    :`n$($priya.body)`n"
}

if ($AgentMailbox) {
    if ($agentOk) {
        Write-Host "Seeded the AGENT mailbox ($AgentMailbox): Maria Garcia / SHP-1234." -ForegroundColor Green
    } else {
        Write-Host "Could not auto-send to the agent mailbox. Send this to ${AgentMailbox}:" -ForegroundColor Yellow
        Write-Host "  Subject : $($maria.subject)"
        Write-Host "  Body    :`n$($maria.body)`n"
    }
} else {
    Write-Host "Agent mailbox not provided — seed it after hiring the autopilot in Teams:" -ForegroundColor Cyan
    Write-Host "  send to the agent-user (e.g. caldova-autopilot@<tenant>) the Maria Garcia / SHP-1234 email above,"
    Write-Host "  or re-run: ./infra/hooks/seed-emails.ps1 -AgentMailbox <agent-upn>"
}
