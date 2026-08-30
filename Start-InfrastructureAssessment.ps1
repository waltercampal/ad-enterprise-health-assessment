<#
.SYNOPSIS
    Starts the v1.1 Infrastructure Assessment.

.DESCRIPTION
    Orchestrates the infrastructure modules that build on top of the
    Foundation assessment: DHCP, Certificate Services, File Services,
    DFS Namespace Health, Event Log Analysis, and Windows Services.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.1.0
#>

Clear-Host
. .\scripts\Common\Common.ps1
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Infrastructure Assessment (v1.1)" -ForegroundColor Cyan
Write-Host " Horizon Labs" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

Initialize-ReportsFolder

Write-Host ""
Write-Host "Starting infrastructure assessment..." -ForegroundColor Yellow

.\scripts\Get-DhcpAssessment.ps1

.\scripts\Get-CertificateServicesAssessment.ps1

.\scripts\Get-FileServicesAssessment.ps1

.\scripts\Get-DfsHealth.ps1

.\scripts\Get-EventLogAnalysis.ps1

.\scripts\Get-WindowsServicesAssessment.ps1

Write-Host ""
Write-Host "Infrastructure assessment completed." -ForegroundColor Green
Write-Host ""
Write-Host "Reports generated in:"
Write-Host ".\reports"
