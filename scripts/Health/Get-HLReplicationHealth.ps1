<#
.SYNOPSIS
    Retrieves Active Directory replication health for all Domain Controllers in the forest.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.2.1
#>

Import-Module ActiveDirectory

$Forest = Get-ADForest

$DomainControllers = foreach ($DomainName in $Forest.Domains)
{
    Get-ADDomainController `
        -Filter * `
        -Server $DomainName
}

$Replication = foreach ($DC in $DomainControllers)
{
    try
    {
        Get-ADReplicationPartnerMetadata `
            -Target $DC.HostName `
            -ErrorAction Stop |
        Select-Object `
            Server,
            Partner,
            Partition,
            LastReplicationSuccess,
            LastReplicationResult,
            ConsecutiveReplicationFailures
    }
    catch
    {
        Write-Warning "Failed to retrieve replication metadata from $($DC.HostName)"

        [PSCustomObject]@{
            Server                         = $DC.HostName
            Partner                        = $null
            Partition                      = $null
            LastReplicationSuccess         = $null
            LastReplicationResult          = "UNREACHABLE"
            ConsecutiveReplicationFailures = $null
        }
    }
}

$Replication |
    Export-Csv `
        -Path ".\reports\ReplicationHealth.csv" `
        -NoTypeInformation `
        -Encoding UTF8

Write-Host ""
Write-Host "Replication health exported successfully." -ForegroundColor Green

return $Replication