<#
.SYNOPSIS
    Retrieves all Domain Controllers in the Active Directory Forest.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.3.1
#>

Import-Module ActiveDirectory

$Forest = Get-ADForest

$DCInventory = foreach ($DomainName in $Forest.Domains)
{
    $DCs = Get-ADDomainController `
        -Server $DomainName `
        -Filter *

    foreach ($DC in $DCs)
    {
        [PSCustomObject]@{

            Forest          = $Forest.Name
            Domain          = $DomainName

            HostName        = $DC.HostName
            Name            = $DC.Name
            Site            = $DC.Site

            IPv4Address     = $DC.IPv4Address
            OperatingSystem = $DC.OperatingSystem

            IsGlobalCatalog = $DC.IsGlobalCatalog
            IsReadOnly      = $DC.IsReadOnly

        }
    }
}

return $DCInventory