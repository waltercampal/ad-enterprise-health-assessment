<#
.SYNOPSIS
    Assesses Microsoft Entra Connect (Azure AD Connect) sync health.

.DESCRIPTION
    Queries every configured Entra Connect server remotely (via PowerShell
    remoting) for its sync scheduler state, the result of each connector's
    last run (best-effort - the ADSync module's run-status API varies by
    version), and recent sync-related events from the Application event
    log (provider "Directory Synchronization") as a version-independent
    fallback for spotting failures. Supports multi-server HA topologies
    (e.g. one active server plus one in staging mode) and flags if more
    than one server is active (not in staging mode) at the same time,
    which risks conflicting writes back to Active Directory.

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
    0.4.0
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
    $EventReport = @()

    foreach ($Server in $EntraConnectServers) {

        try {

            $Result = Invoke-Command -ComputerName $Server -Credential $Credential -ErrorAction Stop -ScriptBlock {
                Import-Module ADSync -ErrorAction Stop

                $Scheduler = Get-ADSyncScheduler

                # Get-ADSyncConnectorRunStatus's parameter set varies across
                # Entra Connect / ADSync module versions (-ConnectorName isn't
                # accepted on all of them). A parameter-binding error is a
                # terminating error that -ErrorAction can't suppress, so try
                # a couple of call shapes and fall back to $null rather than
                # letting one connector's run-status lookup take down the
                # whole server's report.
                $ConnectorRuns = foreach ($Connector in (Get-ADSyncConnector)) {

                    $LastRun = $null
                    try {
                        $LastRun = Get-ADSyncConnectorRunStatus -ConnectorName $Connector.Name -ErrorAction Stop
                    }
                    catch {
                        try {
                            $LastRun = Get-ADSyncConnectorRunStatus $Connector.Name -ErrorAction Stop
                        }
                        catch {
                            # Not available on this ADSync module version - LastRun stays $null.
                        }
                    }

                    [PSCustomObject]@{
                        Name    = $Connector.Name
                        Type    = $Connector.ConnectorTypeName
                        LastRun = $LastRun
                    }
                }

                # Cross-version fallback for "did the last sync cycle succeed":
                # the sync engine (miiserver.exe) logs each run's outcome to the
                # Application event log under provider "Directory Synchronization"
                # regardless of ADSync module version. Surface the raw recent
                # events (level + message) rather than guessing which specific
                # Event ID means success on this version.
                $SyncEvents = $null
                try {
                    $SyncEvents = Get-WinEvent -FilterHashtable @{
                        LogName      = "Application"
                        ProviderName = "Directory Synchronization"
                        StartTime    = (Get-Date).AddHours(-24)
                    } -ErrorAction Stop |
                        Select-Object -First 25 TimeCreated, Id, LevelDisplayName,
                            @{Name = "Message"; Expression = { ($_.Message -split "`r?`n")[0] } }
                }
                catch [System.Exception] {
                    # Get-WinEvent throws when there are simply no matching events
                    # in the window (not a real failure) - leave $SyncEvents empty.
                }

                [PSCustomObject]@{
                    Scheduler     = $Scheduler
                    ConnectorRuns = $ConnectorRuns
                    SyncEvents    = $SyncEvents
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

            foreach ($Evt in $Result.SyncEvents) {
                $EventReport += [PSCustomObject]@{
                    Server      = $Server
                    TimeCreated = $Evt.TimeCreated
                    EventId     = $Evt.Id
                    Level       = $Evt.LevelDisplayName
                    Message     = $Evt.Message
                }
            }

        }
        catch {
            Write-WarningMessage "Could not query Entra Connect status on '$Server': $($_.Exception.Message)"
        }

    }

    $SchedulerReport | Format-Table -AutoSize
    $RunReport | Format-Table -AutoSize
    $EventReport | Format-Table -AutoSize

    Export-AssessmentCsv -Data $SchedulerReport -Name "EntraConnectScheduler"
    Export-AssessmentCsv -Data $RunReport -Name "EntraConnectConnectorRuns"
    Export-AssessmentCsv -Data $EventReport -Name "EntraConnectSyncEvents"

    $ActiveServers = $SchedulerReport | Where-Object { $_.StagingModeEnabled -eq $false }
    if (($ActiveServers | Measure-Object).Count -gt 1) {
        Write-WarningMessage "$($ActiveServers.Count) Entra Connect servers are active (not in staging mode) at the same time - only one should be active to avoid conflicting writes."
    }

    $Failed = $RunReport | Where-Object { $_.LastRunResult -and $_.LastRunResult -ne "success" }
    if ($Failed) {
        Write-WarningMessage "$($Failed.Count) connector run(s) did not complete successfully."
    }

    $ErrorEvents = $EventReport | Where-Object { $_.Level -in @("Error", "Warning") }
    if ($ErrorEvents) {
        Write-WarningMessage "$($ErrorEvents.Count) Warning/Error-level sync event(s) in the Application log (last 24h) - see EntraConnectSyncEvents.csv."
    }

}
catch {
    Write-ErrorMessage "Failed to collect Entra Connect status: $($_.Exception.Message)"
}
