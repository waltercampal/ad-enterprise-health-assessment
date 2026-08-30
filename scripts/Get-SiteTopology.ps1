<#
.SYNOPSIS
    Retrieves Active Directory Site Topology information.

.DESCRIPTION
    Collects information about AD Sites, their subnets, and site links,
    including replication interval and cost, to help identify topology
    issues (orphaned subnets, missing site links, long replication windows).

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.1.0
#>

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Collecting Site Topology..."

if (!(Test-RequiredModule -ModuleName ActiveDirectory)) { return }

try {

    $Sites = Get-ADReplicationSite -Filter * -Properties Description
    $Subnets = Get-ADReplicationSubnet -Filter * -Properties Site
    $SiteLinks = Get-ADReplicationSiteLink -Filter * -Properties Cost, ReplicationFrequencyInMinutes, SitesIncluded

    $SiteReport = foreach ($Site in $Sites) {

        $SiteSubnets = $Subnets | Where-Object { $_.Site -eq $Site.DistinguishedName }

        [PSCustomObject]@{

            SiteName    = $Site.Name
            Description = $Site.Description
            SubnetCount = ($SiteSubnets | Measure-Object).Count
            Subnets     = ($SiteSubnets.Name -join ", ")

        }

    }

    $SiteLinkReport = foreach ($Link in $SiteLinks) {

        [PSCustomObject]@{

            SiteLinkName          = $Link.Name
            Cost                  = $Link.Cost
            ReplicationIntervalMin = $Link.ReplicationFrequencyInMinutes
            SitesIncluded         = ($Link.SitesIncluded -join ", ")

        }

    }

    $SiteReport | Format-Table -AutoSize
    $SiteLinkReport | Format-Table -AutoSize

    Export-AssessmentCsv -Data $SiteReport -Name "SiteTopology"
    Export-AssessmentCsv -Data $SiteLinkReport -Name "SiteLinks"

    $OrphanSubnets = $Subnets | Where-Object { -not $_.Site }
    if ($OrphanSubnets) {
        Write-WarningMessage "$($OrphanSubnets.Count) subnet(s) are not assigned to any site."
    }

}
catch {
    Write-ErrorMessage "Failed to collect Site Topology: $($_.Exception.Message)"
}
