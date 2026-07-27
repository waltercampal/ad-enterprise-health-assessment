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

# Forest information
$Forest = Get-ADForest

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

$Sites |
    Export-Csv `
        -Path ".\reports\SitesInformation.csv" `
        -NoTypeInformation `
        -Encoding UTF8

Write-Host ""
Write-Host "Sites information exported successfully." -ForegroundColor Green

return $Sites