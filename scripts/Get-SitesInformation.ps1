<#
.SYNOPSIS
    Retrieves Active Directory Sites information.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.2.2
#>

Import-Module ActiveDirectory

# Retrieve all objects only once
$AllSites = Get-ADReplicationSite -Filter *

$AllSubnets = Get-ADReplicationSubnet -Filter *

$AllDCs = Get-ADDomainController -Filter *

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