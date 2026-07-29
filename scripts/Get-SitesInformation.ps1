<#
.SYNOPSIS
    Retrieves Active Directory Sites information.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.2.2
#>

param(
    [System.Management.Automation.PSCredential]$Credential
)

Import-Module ActiveDirectory

$CredSplat = if ($Credential) { @{ Credential = $Credential } } else { @{} }

# Retrieve all objects only once
$AllSites = Get-ADReplicationSite -Filter * @CredSplat

$AllSubnets = Get-ADReplicationSubnet -Filter * @CredSplat

$AllDCs = Get-ADDomainController -Filter * @CredSplat

$Sites = foreach ($Site in ($AllSites | Sort-Object Name))
{
    $SiteDCs = $AllDCs | Where-Object {
        $_.Site -eq $Site.Name
    }

    $SiteSubnets = $AllSubnets | Where-Object {
        $_.Site -like "CN=$($Site.Name),*"
    }

    [PSCustomObject]@{
        SiteName          = $Site.Name
        DomainControllers = @($SiteDCs).Count
        Subnets           = @($SiteSubnets).Count
    }
}

return $Sites