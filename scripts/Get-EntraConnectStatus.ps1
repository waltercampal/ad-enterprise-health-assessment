<#
.SYNOPSIS
    Assesses Microsoft Entra Connect (Azure AD Connect) sync health.

.DESCRIPTION
    Must be run ON the Entra Connect sync server. Reports the sync
    scheduler configuration and the result of the last connector run
    for each configured connector (AD and Entra ID).

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.1.0
#>

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Collecting Entra Connect Sync status..."

if (!(Test-RequiredModule -ModuleName ADSync)) {
    Write-WarningMessage "This check must run on the Entra Connect sync server (ADSync module not found here)."
    return
}

try {

    $Scheduler = Get-ADSyncScheduler

    $SchedulerInfo = [PSCustomObject]@{

        SyncCycleEnabled       = $Scheduler.SyncCycleEnabled
        SyncCycleInProgress    = $Scheduler.SyncCycleInProgress
        NextSyncCycleStartTime = $Scheduler.NextSyncCycleStartTimeInUTC
        LastSyncCycleStartTime = $Scheduler.LastSyncCycleStartTimeInUTC

    }

    $SchedulerInfo | Format-List

    Export-AssessmentCsv -Data $SchedulerInfo -Name "EntraConnectScheduler"

    $Connectors = Get-ADSyncConnector

    $RunReport = foreach ($Connector in $Connectors) {

        $LastRun = Get-ADSyncConnectorRunStatus -ConnectorName $Connector.Name -ErrorAction SilentlyContinue

        [PSCustomObject]@{

            ConnectorName = $Connector.Name
            ConnectorType = $Connector.ConnectorTypeName
            LastRunResult = $LastRun.RunResult
            LastRunDate   = $LastRun.RunHistoryDate

        }

    }

    $RunReport | Format-Table -AutoSize

    Export-AssessmentCsv -Data $RunReport -Name "EntraConnectConnectorRuns"

    $Failed = $RunReport | Where-Object { $_.LastRunResult -and $_.LastRunResult -ne "success" }
    if ($Failed) {
        Write-WarningMessage "$($Failed.Count) connector(s) did not complete their last run successfully."
    }

}
catch {
    Write-ErrorMessage "Failed to collect Entra Connect status: $($_.Exception.Message)"
}
