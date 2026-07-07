<#
.SYNOPSIS
    Retrieves an inventory of all Domain Controllers in the Active Directory forest.

.DESCRIPTION
    Collects information about each Domain Controller including:
    - Hostname
    - Domain
    - Site
    - IPv4 Address
    - Operating System
    - Global Catalog
    - Read Only DC
    - Availability

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.1.0
#>

Import-Module ActiveDirectory

$DomainControllers = Get-ADDomainController -Filter *

$Inventory = foreach ($DC in $DomainControllers) {

    [PSCustomObject]@{

        Name            = $DC.HostName
        Domain          = $DC.Domain
        Site            = $DC.Site
        IPv4Address     = $DC.IPv4Address
        OperatingSystem = $DC.OperatingSystem
        GlobalCatalog   = $DC.IsGlobalCatalog
        ReadOnly        = $DC.IsReadOnly

        Online = if (Test-Connection $DC.HostName -Count 1 -Quiet) {
            "Yes"
        }
        else {
            "No"
        }

    }

}

$Inventory | Sort-Object Name

$Inventory |
Export-Csv `
-Path ".\reports\DomainControllerInventory.csv" `
-NoTypeInformation `
-Encoding UTF8

Write-Host ""
Write-Host "Assessment completed successfully." -ForegroundColor Green
Write-Host ""
Write-Host "Inventory exported to:"
Write-Host ".\reports\DomainControllerInventory.csv"
