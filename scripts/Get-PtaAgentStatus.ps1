<#
.SYNOPSIS
    Checks the health of Pass-through Authentication (PTA) agents.

.DESCRIPTION
    Queries the "Azure AD Connect Authentication Agent" service status on
    each configured PTA agent server via PowerShell remoting. Edit
    $PtaAgentServers to match your environment (typically the Entra
    Connect server plus any standalone PTA agent servers deployed for
    redundancy).

.PARAMETER Credential
    Credential to remote into each PTA agent server with (needs local
    admin rights there). If omitted, and the servers list is non-empty,
    you'll be prompted once.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.2.0
#>

param(
    [PSCredential]$Credential
)

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Collecting PTA Agent status..."

# Edit this list to match your environment's PTA agent servers.
$PtaAgentServers = @()

if ($PtaAgentServers.Count -eq 0) {
    Write-WarningMessage "No PTA agent servers configured. Edit `$PtaAgentServers in this script and re-run."
    return
}

if (!$Credential) {
    $Credential = Get-Credential -Message "Credentials for PTA agent servers (needs local admin rights on each server)"
}

try {

    $PtaReport = foreach ($AgentServer in $PtaAgentServers) {

        try {
            $Service = Invoke-Command -ComputerName $AgentServer -Credential $Credential -ErrorAction Stop -ScriptBlock {
                Get-Service -Name "AzureADConnectAuthenticationAgentService" -ErrorAction Stop
            }

            [PSCustomObject]@{
                Server  = $AgentServer
                Status  = $Service.Status
                Healthy = ($Service.Status -eq "Running")
            }
        }
        catch {
            Write-WarningMessage "Could not query PTA agent on '$AgentServer': $($_.Exception.Message)"
            [PSCustomObject]@{
                Server  = $AgentServer
                Status  = "Unreachable"
                Healthy = $false
            }
        }

    }

    $PtaReport | Format-Table -AutoSize

    Export-AssessmentCsv -Data $PtaReport -Name "PtaAgentStatus"

    $Down = $PtaReport | Where-Object { -not $_.Healthy }
    if ($Down) {
        Write-WarningMessage "$($Down.Count) PTA agent(s) not running — authentication redundancy at risk."
    }

}
catch {
    Write-ErrorMessage "Failed to collect PTA Agent status: $($_.Exception.Message)"
}
