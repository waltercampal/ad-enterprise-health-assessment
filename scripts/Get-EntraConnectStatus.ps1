<#
.SYNOPSIS
    Assesses Microsoft Entra Connect (Azure AD Connect) sync health.

.DESCRIPTION
    Queries every configured Entra Connect server remotely (via PowerShell
    remoting) for its sync scheduler state and the result of each
    connector's last run. Supports multi-server HA topologies (e.g. one
    active server plus one in staging mode) and flags if more than one
    server is active (not in staging mode) at the same time, which risks
    conflicting writes back to Active Directory.

    Each target server needs the ADSync module installed locally (it is,
    wherever Entra Connect itself is installed) and must allow incoming
    PowerShell remoting (WinRM) from wherever this script runs.

.PARAMETER Credential
    Credential to remote into each Entra Connect server with (needs local
    admin rights there). If omitted, and the servers list is non-empty,
    you'll be prompted once.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.3.0
#>

param(
    [PSCredential]$Credential
)

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Collecting Entra Connect Sync status..."

# Edit this list to match your environment's Entra Connect (Azure AD Connect)
# sync servers - e.g. an active server plus a staging-mode server for HA.
$EntraConnectServers = @()

if ($EntraConnectServers.Count -eq 0) {
    Write-WarningMessage "No Entra Connect servers configured. Edit `$EntraConnectServers in this script and re-run."
    return
}

if (!$Credential) {
    $Credential = Get-Credential -Message "Credentials for Entra Connect servers (needs local admin rights on each server)"
}

try {

    $SchedulerReport = @()
    $RunReport = @()

    foreach ($Server in $EntraConnectServers) {

        try {

            $Result = Invoke-Command -ComputerName $Server -Credential $Credential -ErrorAction Stop -ScriptBlock {
                Import-Module ADSync -ErrorAction Stop

                $Scheduler = Get-ADSyncScheduler

                $ConnectorRuns = foreach ($Connector in (Get-ADSyncConnector)) {
                    [PSCustomObject]@{
                        Name    = $Connector.Name
                        Type    = $Connector.ConnectorTypeName
                        LastRun = Get-ADSyncConnectorRunStatus -ConnectorName $Connector.Name -ErrorAction SilentlyContinue
                    }
                }

                [PSCustomObject]@{
                    Scheduler     = $Scheduler
                    ConnectorRuns = $ConnectorRuns
                }
            }

            $SchedulerReport += [PSCustomObject]@{
                Server                 = $Server
                SyncCycleEnabled       = $Result.Scheduler.SyncCycleEnabled
                SyncCycleInProgress    = $Result.Scheduler.SyncCycleInProgress
                StagingModeEnabled     = $Result.Scheduler.StagingModeEnabled
                NextSyncCycleStartTime = $Result.Scheduler.NextSyncCycleStartTimeInUTC
                LastSyncCycleStartTime = $Result.Scheduler.LastSyncCycleStartTimeInUTC
            }

            foreach ($Connector in $Result.ConnectorRuns) {
                $RunReport += [PSCustomObject]@{
                    Server        = $Server
                    ConnectorName = $Connector.Name
                    ConnectorType = $Connector.Type
                    LastRunResult = $Connector.LastRun.RunResult
                    LastRunDate   = $Connector.LastRun.RunHistoryDate
                }
            }

        }
        catch {
            Write-WarningMessage "Could not query Entra Connect status on '$Server': $($_.Exception.Message)"
        }

    }

    $SchedulerReport | Format-Table -AutoSize
    $RunReport | Format-Table -AutoSize

    Export-AssessmentCsv -Data $SchedulerReport -Name "EntraConnectScheduler"
    Export-AssessmentCsv -Data $RunReport -Name "EntraConnectConnectorRuns"

    $ActiveServers = $SchedulerReport | Where-Object { $_.StagingModeEnabled -eq $false }
    if (($ActiveServers | Measure-Object).Count -gt 1) {
        Write-WarningMessage "$($ActiveServers.Count) Entra Connect servers are active (not in staging mode) at the same time - only one should be active to avoid conflicting writes."
    }

    $Failed = $RunReport | Where-Object { $_.LastRunResult -and $_.LastRunResult -ne "success" }
    if ($Failed) {
        Write-WarningMessage "$($Failed.Count) connector run(s) did not complete successfully."
    }

}
catch {
    Write-ErrorMessage "Failed to collect Entra Connect status: $($_.Exception.Message)"
}
