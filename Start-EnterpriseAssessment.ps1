<#
.SYNOPSIS
    Runs the complete Enterprise Active Directory Health Assessment.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.3.0
#>

Import-Module ActiveDirectory

$Forest = Get-ADForest

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Enterprise AD Health Assessment" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$Forest      = .\scripts\Get-ForestInformation.ps1
$Domains     = .\scripts\Get-DomainInformation.ps1
$FSMO        = .\scripts\Get-FSMORoles.ps1
$DCs         = .\scripts\Get-DomainControllerInventory.ps1
$Replication = .\scripts\Health\Get-HLReplicationHealth.ps1
$Sites       = .\scripts\Get-SitesInformation.ps1

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host " Assessment completed successfully." -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""

Write-Host "Forest............... $($Forest.ForestName)"
Write-Host "Domains.............. $($Forest.DomainCount)"
Write-Host "Domain Controllers... $($DCs.Count)"
Write-Host "Replication Entries.. $($Replication.Count)"
Write-Host "Sites................ $($Sites.Count)"

$Summary = .\scripts\Reporting\Get-ExecutiveSummary.ps1 `
    -Forest $Forest `
    -Domains $Domains `
    -FSMO $FSMO `
    -DCs $DCs `
    -Replication $Replication