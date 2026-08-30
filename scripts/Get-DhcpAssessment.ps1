<#
.SYNOPSIS
    Assesses DHCP server configuration and scope utilization.

.DESCRIPTION
    Collects authorized DHCP servers from Active Directory, then queries
    each one for its IPv4 scopes and utilization percentage, flagging
    scopes at risk of exhaustion.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.1.0
#>

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Collecting DHCP Assessment..."

if (!(Test-RequiredModule -ModuleName DhcpServer)) { return }

try {

    $DhcpServers = Get-DhcpServerInDC

    $ScopeReport = foreach ($Server in $DhcpServers) {

        try {

            $Scopes = Get-DhcpServerv4Scope -ComputerName $Server.DnsName -ErrorAction Stop

            foreach ($Scope in $Scopes) {

                $Stats = Get-DhcpServerv4ScopeStatistics -ComputerName $Server.DnsName -ScopeId $Scope.ScopeId -ErrorAction SilentlyContinue

                [PSCustomObject]@{

                    Server            = $Server.DnsName
                    ScopeId           = $Scope.ScopeId
                    Name              = $Scope.Name
                    State             = $Scope.State
                    StartRange        = $Scope.StartRange
                    EndRange          = $Scope.EndRange
                    PercentageInUse   = $Stats.PercentageInUse
                    AddressesFree     = $Stats.Free
                    AddressesInUse    = $Stats.InUse

                }

            }

        }
        catch {
            Write-WarningMessage "Could not query DHCP server $($Server.DnsName): $($_.Exception.Message)"
        }

    }

    $ScopeReport | Format-Table -AutoSize

    Export-AssessmentCsv -Data $ScopeReport -Name "DhcpScopes"

    $NearFull = $ScopeReport | Where-Object { $_.PercentageInUse -ge 85 }
    if ($NearFull) {
        Write-WarningMessage "$($NearFull.Count) scope(s) at 85%+ utilization."
    }

}
catch {
    Write-ErrorMessage "Failed to collect DHCP Assessment: $($_.Exception.Message)"
}
