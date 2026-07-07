<#
.SYNOPSIS
    Starts the Enterprise Active Directory Health Assessment.

.DESCRIPTION
    Orchestrates all assessment modules and generates the final reports.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.1.0
#>

Clear-Host

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Enterprise Active Directory Assessment" -ForegroundColor Cyan
Write-Host " Horizon Labs" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$ReportPath = ".\reports"

if (!(Test-Path $ReportPath)) {
    New-Item -ItemType Directory -Path $ReportPath | Out-Null
}

Write-Host "Starting assessment..." -ForegroundColor Yellow

.\scripts\Get-ForestInformation.ps1

.\scripts\Get-DomainInformation.ps1

.\scripts\Get-FSMORoles.ps1

.\scripts\Get-DomainControllerInventory.ps1

Write-Host ""
Write-Host "Assessment completed successfully." -ForegroundColor Green
Write-Host ""
Write-Host "Reports generated in:"
Write-Host $ReportPath
