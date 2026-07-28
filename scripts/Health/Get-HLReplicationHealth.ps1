<#
.SYNOPSIS
    Retrieves Active Directory replication health for all Domain Controllers in the forest.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    1.1.0
#>

function Get-HLReplicationHealth {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$DomainControllers
    )

    $Results = @()

    foreach ($DC in $DomainControllers) {

        Write-Verbose "Checking replication health on $($DC.HostName)"

        try {
            $ReplicationMetadata = Get-ADReplicationPartnerMetadata `
                -Target $DC.HostName `
                -ErrorAction Stop

            foreach ($Partner in $ReplicationMetadata) {

                if ($Partner.LastReplicationResult -eq 0) {
                    $Results += New-HealthResult `
                        -Category "Replication" `
                        -Check "Replication Partner" `
                        -Target $Partner.Partner `
                        -Status Healthy `
                        -Severity Info `
                        -Message "Replication completed successfully."
                }
                else {
                    $Results += New-HealthResult `
                        -Category "Replication" `
                        -Check "Replication Partner" `
                        -Target $Partner.Partner `
                        -Status Critical `
                        -Severity High `
                        -Message "Replication failed. Error code: $($Partner.LastReplicationResult)" `
                        -Recommendation "Investigate Active Directory replication for this partner."
                }
            }
        }
        catch {

            Write-Warning "Failed to retrieve replication metadata from $($DC.HostName)"

            $Results += New-HealthResult `
                -Category "Replication" `
                -Check "Domain Controller Reachability" `
                -Target $DC.HostName `
                -Status Warning `
                -Severity Medium `
                -Message "Unable to retrieve replication metadata." `
                -Recommendation "Verify connectivity, AD Web Services and Domain Controller availability."
        }
    }

    return $Results
}
