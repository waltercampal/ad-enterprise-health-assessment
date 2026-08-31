<#
.SYNOPSIS
    Assesses DNS server configuration on each Domain Controller.

.DESCRIPTION
    Collects DNS zone inventory, forwarders, and scavenging configuration
    from each Domain Controller running the DNS Server role.

.AUTHOR
    Walter Campal
    Horizon Labs

.PARAMETER Credential
    Optional alternate credential to query every domain/DNS server with.
    The DnsServer module cmdlets don't take -Credential directly, so this
    opens a credentialed CIM session per server instead.

.VERSION
    0.2.0
#>

param(
    [PSCredential]$Credential
)

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Collecting DNS Assessment..."

if (!(Test-RequiredModule -ModuleName ActiveDirectory)) { return }

try {

    $DomainControllers = Get-ForestDomainControllers -Credential $Credential
    $ZoneReport = @()
    $ServerReport = @()

    foreach ($DC in $DomainControllers) {

        $CimSession = $null

        try {

            # Get-DnsServerZone/-Forwarder/-Scavenging don't accept -Credential
            # directly - go through a credentialed CIM session instead when
            # one was supplied, falling back to plain -ComputerName otherwise.
            $DnsParams = @{}
            if ($Credential) {
                $CimSession = New-CimSession -ComputerName $DC.HostName -Credential $Credential -ErrorAction Stop
                $DnsParams["CimSession"] = $CimSession
            }
            else {
                $DnsParams["ComputerName"] = $DC.HostName
            }

            $Zones = Get-DnsServerZone @DnsParams -ErrorAction Stop

            $ZoneReport += foreach ($Zone in $Zones) {
                [PSCustomObject]@{
                    Server      = $DC.HostName
                    ZoneName    = $Zone.ZoneName
                    ZoneType    = $Zone.ZoneType
                    IsDsIntegrated = $Zone.IsDsIntegrated
                    IsSigned    = $Zone.IsSigned
                    Dynamic     = $Zone.DynamicUpdate
                }
            }

            $Forwarders = Get-DnsServerForwarder @DnsParams -ErrorAction SilentlyContinue
            $Scavenging = Get-DnsServerScavenging @DnsParams -ErrorAction SilentlyContinue

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
        finally {
            if ($CimSession) { Remove-CimSession $CimSession -ErrorAction SilentlyContinue }
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
