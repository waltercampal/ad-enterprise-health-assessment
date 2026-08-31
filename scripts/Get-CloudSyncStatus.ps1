<#
.SYNOPSIS
    Checks the health of Microsoft Entra Cloud Sync agents.

.DESCRIPTION
    Queries the "Microsoft Azure AD Connect Provisioning Agent" service
    status on each configured Cloud Sync agent server via PowerShell
    remoting. Edit $CloudSyncAgentServers to match your environment.

.PARAMETER Credential
    Credential to remote into each Cloud Sync agent server with (needs
    local admin rights there). If omitted, and the servers list is
    non-empty, you'll be prompted once.

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

Write-Step "Collecting Cloud Sync Agent status..."

# Edit this list to match your environment's Cloud Sync agent servers.
$CloudSyncAgentServers = @()

if ($CloudSyncAgentServers.Count -eq 0) {
    Write-WarningMessage "No Cloud Sync agent servers configured. Edit `$CloudSyncAgentServers in this script and re-run."
    return
}

if (!$Credential) {
    $Credential = Get-Credential -Message "Credentials for Cloud Sync agent servers (needs local admin rights on each server)"
}

try {

    $CloudSyncReport = foreach ($AgentServer in $CloudSyncAgentServers) {

        try {
            $Service = Invoke-Command -ComputerName $AgentServer -Credential $Credential -ErrorAction Stop -ScriptBlock {
                Get-Service -Name "AzureADConnectProvisioningAgentService" -ErrorAction Stop
            }

            [PSCustomObject]@{
                Server  = $AgentServer
                Status  = $Service.Status
                Healthy = ($Service.Status -eq "Running")
            }
        }
        catch {
            Write-WarningMessage "Could not query Cloud Sync agent on '$AgentServer': $($_.Exception.Message)"
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
