<#
.SYNOPSIS
    Starts the Enterprise Active Directory Health Assessment.

.DESCRIPTION
    Orchestrates all assessment modules and generates the final reports.
    Prompts once for a credential and passes it to every module, so you
    can run this as an account that isn't necessarily the one you're
    logged into Windows with (e.g. one with the right permissions across
    every domain in a multi-domain forest). Most Foundation checks are
    plain read access - only the Get-GPOReport-free GPO metadata call
    (Get-GPO itself) can't take an alternate credential; see
    Get-GPOInventory.ps1's own notes.

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
Write-Host " Enterprise Active Directory Assessment" -ForegroundColor Cyan
Write-Host " Horizon Labs" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Initialize-ReportsFolder

$Credential = Get-Credential -Message "Credentials to run the Foundation assessment with (needs read access across every domain in the forest)"

Write-Host "Starting assessment..." -ForegroundColor Yellow

.\scripts\Get-ForestInformation.ps1 -Credential $Credential

.\scripts\Get-DomainInformation.ps1 -Credential $Credential

.\scripts\Get-FSMORoles.ps1 -Credential $Credential

.\scripts\Get-DomainControllerInventory.ps1 -Credential $Credential

.\scripts\Get-SiteTopology.ps1 -Credential $Credential

.\scripts\Get-ReplicationStatus.ps1 -Credential $Credential

.\scripts\Get-SysvolHealth.ps1 -Credential $Credential

.\scripts\Get-DnsAssessment.ps1 -Credential $Credential

.\scripts\Get-GPOInventory.ps1 -Credential $Credential

.\scripts\Get-SecurityBaseline.ps1 -Credential $Credential

Write-Host ""
Write-Host "Assessment completed successfully." -ForegroundColor Green
Write-Host ""
Write-Host "Reports generated in:"
Write-Host ".\reports"
