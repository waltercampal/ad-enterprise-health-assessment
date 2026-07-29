<#
.SYNOPSIS
    Retrieves all Domain Controllers in the Active Directory Forest.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.3.1
#>

param(
    [System.Management.Automation.PSCredential]$Credential
)

Import-Module ActiveDirectory

$CredSplat = if ($Credential) { @{ Credential = $Credential } } else { @{} }

$Forest = Get-ADForest @CredSplat

$DCInventory = foreach ($DomainName in $Forest.Domains)
{
    $DCs = Get-ADDomainController `
        -Server $DomainName `
        -Filter * `
        @CredSplat

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