<#
.SYNOPSIS
    Assesses DNS server configuration on each Domain Controller.

.DESCRIPTION
    Collects DNS zone inventory, forwarders, and scavenging configuration
    from each Domain Controller running the DNS Server role.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.1.0
#>

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Collecting DNS Assessment..."

if (!(Test-RequiredModule -ModuleName ActiveDirectory)) { return }

try {

    $DomainControllers = Get-ADDomainController -Filter *
    $ZoneReport = @()
    $ServerReport = @()

    foreach ($DC in $DomainControllers) {

        try {

            $Zones = Get-DnsServerZone -ComputerName $DC.HostName -ErrorAction Stop

            foreach ($Zone in $Zones) {
                $ZoneReport += [PSCustomObject]@{
                    Server      = $DC.HostName
                    ZoneName    = $Zone.ZoneName
                    ZoneType    = $Zone.ZoneType
                    IsDsIntegrated = $Zone.IsDsIntegrated
                    IsSigned    = $Zone.IsSigned
                    Dynamic     = $Zone.DynamicUpdate
                }
            }

            $Forwarders = Get-DnsServerForwarder -ComputerName $DC.HostName -ErrorAction SilentlyContinue
            $Scavenging = Get-DnsServerScavenging -ComputerName $DC.HostName -ErrorAction SilentlyContinue

            $ServerReport += [PSCustomObject]@{
                Server            = $DC.HostName
                Forwarders        = ($Forwarders.IPAddress -join ", ")
                ScavengingEnabled = $Scavenging.ScavengingState
                RefreshInterval   = $Scavenging.RefreshInterval
                NoRefreshInterval = $Scavenging.NoRefreshInterval
            }

        }
        catch {
            Write-WarningMessage "Could not query DNS on $($DC.HostName): $($_.Exception.Message)"
        }

    }

    $ZoneReport | Format-Table -AutoSize
    $ServerReport | Format-Table -AutoSize

    Export-AssessmentCsv -Data $ZoneReport -Name "DnsZones"
    Export-AssessmentCsv -Data $ServerReport -Name "DnsServers"

}
catch {
    Write-ErrorMessage "Failed to collect DNS Assessment: $($_.Exception.Message)"
}
