<#
.SYNOPSIS
    Starts the v2.0 Hybrid Identity Assessment.

.DESCRIPTION
    Orchestrates the Entra ID / hybrid identity modules: Entra Connect
    sync health, Entra ID tenant assessment, PTA agent status, Cloud Sync
    agent status, and Conditional Access review.

    NOTE: The Entra ID and Conditional Access checks use Microsoft Graph
    and will prompt for interactive sign-in (Connect-MgGraph). Run this
    separately from the unattended on-prem assessments.

    NOTE: Get-EntraConnectStatus.ps1, Get-PtaAgentStatus.ps1, and
    Get-CloudSyncStatus.ps1 each need their server list edited to match
    your environment (see the top of each script) before they'll do
    anything other than print a warning and skip. If any of them are
    configured, this orchestrator prompts once for the on-prem remoting
    credential and passes it to all three, instead of each one prompting
    separately.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.2.0
#>

Clear-Host
. .\scripts\Common\Common.ps1
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Hybrid Identity Assessment (v2.0)" -ForegroundColor Cyan
Write-Host " Horizon Labs" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

Initialize-ReportsFolder

Write-Host ""
Write-Host "Starting hybrid identity assessment..." -ForegroundColor Yellow

$OnPremCredential = Get-Credential -Message "Credentials for on-prem Entra Connect/PTA/Cloud Sync servers (needs local admin rights on each - leave blank/Cancel to skip if none of them are configured)"

.\scripts\Get-EntraConnectStatus.ps1 -Credential $OnPremCredential

.\scripts\Get-PtaAgentStatus.ps1 -Credential $OnPremCredential

.\scripts\Get-CloudSyncStatus.ps1 -Credential $OnPremCredential

.\scripts\Get-EntraIdAssessment.ps1

.\scripts\Get-ConditionalAccessReview.ps1

Write-Host ""
Write-Host "Hybrid identity assessment completed." -ForegroundColor Green
Write-Host ""
Write-Host "Reports generated in:"
Write-Host ".\reports"
