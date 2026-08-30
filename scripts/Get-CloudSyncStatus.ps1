<#
.SYNOPSIS
    Checks the health of Microsoft Entra Cloud Sync agents.

.DESCRIPTION
    Queries the "Microsoft Azure AD Connect Provisioning Agent" service
    status on each configured Cloud Sync agent server. Edit
    $CloudSyncAgentServers to match your environment.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.1.0
#>

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Collecting Cloud Sync Agent status..."

# Edit this list to match your environment's Cloud Sync agent servers.
$CloudSyncAgentServers = @()

if ($CloudSyncAgentServers.Count -eq 0) {
    Write-WarningMessage "No Cloud Sync agent servers configured. Edit `$CloudSyncAgentServers in this script and re-run."
    return
}

try {

    $CloudSyncReport = foreach ($AgentServer in $CloudSyncAgentServers) {

        try {
            $Service = Get-Service -ComputerName $AgentServer -Name "AzureADConnectProvisioningAgentService" -ErrorAction Stop

            [PSCustomObject]@{
                Server  = $AgentServer
                Status  = $Service.Status
                Healthy = ($Service.Status -eq "Running")
            }
        }
        catch {
            [PSCustomObject]@{
                Server  = $AgentServer
                Status  = "Unreachable"
                Healthy = $false
            }
        }

    }

    $CloudSyncReport | Format-Table -AutoSize

    Export-AssessmentCsv -Data $CloudSyncReport -Name "CloudSyncStatus"

    $Down = $CloudSyncReport | Where-Object { -not $_.Healthy }
    if ($Down) {
        Write-WarningMessage "$($Down.Count) Cloud Sync agent(s) not running."
    }

}
catch {
    Write-ErrorMessage "Failed to collect Cloud Sync status: $($_.Exception.Message)"
}
