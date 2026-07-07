<#
.SYNOPSIS
    Retrieves all FSMO role holders in the Active Directory Forest.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.1.0
#>

Import-Module ActiveDirectory

$Forest = Get-ADForest
$Domain = Get-ADDomain

$FSMO = [PSCustomObject]@{

    SchemaMaster       = $Forest.SchemaMaster
    DomainNamingMaster = $Forest.DomainNamingMaster
    PDCEmulator        = $Domain.PDCEmulator
    RIDMaster          = $Domain.RIDMaster
    InfrastructureMaster = $Domain.InfrastructureMaster

}

$FSMO

$FSMO |
Export-Csv `
-Path ".\reports\FSMORoles.csv" `
-NoTypeInformation `
-Encoding UTF8

Write-Host ""
Write-Host "FSMO roles exported successfully." -ForegroundColor Green
