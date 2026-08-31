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

.PARAMETER Credential
    Optional alternate credential to query every DHCP server with. The
    DhcpServer module cmdlets don't reliably support -Credential across
    versions, so this remotes into each server via PowerShell remoting
    (WinRM) instead and runs the scope queries there.

.VERSION
    0.2.0
#>

param(
    [PSCredential]$Credential
)

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Collecting DHCP Assessment..."

if (!(Test-RequiredModule -ModuleName DhcpServer)) { return }

try {

    $DhcpServers = Get-DhcpServerInDC

    $ScopeReport = foreach ($Server in $DhcpServers) {

        try {

            if ($Credential) {
                $Scopes = Invoke-Command -ComputerName $Server.DnsName -Credential $Credential -ErrorAction Stop -ScriptBlock {
                    Get-DhcpServerv4Scope | ForEach-Object {
                        $Stats = Get-DhcpServerv4ScopeStatistics -ScopeId $_.ScopeId -ErrorAction SilentlyContinue
                        [PSCustomObject]@{
                            ScopeId         = $_.ScopeId
                            Name            = $_.Name
                            State           = $_.State
                            StartRange      = $_.StartRange
                            EndRange        = $_.EndRange
                            PercentageInUse = $Stats.PercentageInUse
                            AddressesFree   = $Stats.Free
                            AddressesInUse  = $Stats.InUse
                        }
                    }
                }
            }
            else {
                $Scopes = Get-DhcpServerv4Scope -ComputerName $Server.DnsName -ErrorAction Stop | ForEach-Object {
                    $Stats = Get-DhcpServerv4ScopeStatistics -ComputerName $Server.DnsName -ScopeId $_.ScopeId -ErrorAction SilentlyContinue
                    [PSCustomObject]@{
                        ScopeId         = $_.ScopeId
                        Name            = $_.Name
                        State           = $_.State
                        StartRange      = $_.StartRange
                        EndRange        = $_.EndRange
                        PercentageInUse = $Stats.PercentageInUse
                        AddressesFree   = $Stats.Free
                        AddressesInUse  = $Stats.InUse
                    }
                }
            }

            foreach ($Scope in $Scopes) {

                [PSCustomObject]@{

                    Server            = $Server.DnsName
                    ScopeId           = $Scope.ScopeId
                    Name              = $Scope.Name
                    State             = $Scope.State
                    StartRange        = $Scope.StartRange
                    EndRange          = $Scope.EndRange
                    PercentageInUse   = $Scope.PercentageInUse
                    AddressesFree     = $Scope.AddressesFree
                    AddressesInUse    = $Scope.AddressesInUse

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
