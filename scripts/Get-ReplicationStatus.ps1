<#
.SYNOPSIS
    Assesses Active Directory replication health between Domain Controllers.

.DESCRIPTION
    Collects replication partner metadata for every Domain Controller,
    including last replication result, last success time, and consecutive
    failure counts, to identify replication problems across the forest.

.AUTHOR
    Walter Campal
    Horizon Labs

.PARAMETER Credential
    Optional alternate credential to query every domain/DC with.

.VERSION
    0.2.0
#>

param(
    [PSCredential]$Credential
)

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Collecting Replication Status..."

if (!(Test-RequiredModule -ModuleName ActiveDirectory)) { return }

try {

    $DomainControllers = Get-ForestDomainControllers -Credential $Credential

    $AdParams = @{ ErrorAction = "Stop" }
    if ($Credential) { $AdParams["Credential"] = $Credential }

    $ReplicationReport = foreach ($DC in $DomainControllers) {

        try {

            $Partners = Get-ADReplicationPartnerMetadata -Target $DC.HostName @AdParams

            foreach ($Partner in $Partners) {

                [PSCustomObject]@{

                    Server                       = $DC.HostName
                    Partner                      = $Partner.Partner
                    Partition                    = $Partner.Partition
                    LastReplicationSuccess       = $Partner.LastReplicationSuccess
                    LastReplicationResult        = $Partner.LastReplicationResult
                    ConsecutiveReplicationFailures = $Partner.ConsecutiveReplicationFailures
                    Status = if ($Partner.LastReplicationResult -eq 0) { "OK" } else { "FAILURE" }

                }

            }

        }
        catch {
            Write-WarningMessage "Could not query replication metadata from $($DC.HostName): $($_.Exception.Message)"
        }

    }

    $ReplicationReport | Format-Table -AutoSize

    Export-AssessmentCsv -Data $ReplicationReport -Name "ReplicationStatus"

    $Failures = $ReplicationReport | Where-Object { $_.Status -eq "FAILURE" }
    if ($Failures) {
        Write-WarningMessage "$($Failures.Count) replication link(s) reporting failures."
    }
    else {
        Write-Success "No replication failures detected."
    }

}
catch {
    Write-ErrorMessage "Failed to collect Replication Status: $($_.Exception.Message)"
}
