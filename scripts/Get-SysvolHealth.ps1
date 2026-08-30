<#
.SYNOPSIS
    Assesses SYSVOL / DFSR replication health.

.DESCRIPTION
    Reports the DFSR SYSVOL replication state for each Domain Controller
    (Uninitialized, Initialized, Initial Sync, Auto Recovery, Normal, etc.).
    Falls back to a warning when the DFSR module is unavailable (e.g. legacy
    FRS-based SYSVOL replication, or the check is not run on a DC).

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.1.0
#>

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Collecting SYSVOL / DFSR Health..."

if (!(Test-RequiredModule -ModuleName ActiveDirectory)) { return }

try {

    $DomainControllers = Get-ForestDomainControllers

    $SysvolReport = foreach ($DC in $DomainControllers) {

        $State = "Unknown"
        $Note  = ""

        try {
            $DfsrState = Get-WmiObject -Namespace "root\MicrosoftDFS" `
                -Class "DfsrReplicatedFolderInfo" `
                -ComputerName $DC.HostName `
                -Filter "ReplicatedFolderName='SYSVOL Share'" `
                -ErrorAction Stop

            $State = switch ($DfsrState.State) {
                0 { "Uninitialized" }
                1 { "Initialized" }
                2 { "Initial Sync" }
                3 { "Auto Recovery" }
                4 { "Normal" }
                5 { "In Error" }
                default { "Unknown ($($DfsrState.State))" }
            }
        }
        catch {
            $State = "Not Queried"
            $Note  = "DFSR WMI namespace unreachable (legacy FRS or connectivity issue)."
        }

        [PSCustomObject]@{

            Server = $DC.HostName
            State  = $State
            Note   = $Note

        }

    }

    $SysvolReport | Format-Table -AutoSize

    Export-AssessmentCsv -Data $SysvolReport -Name "SysvolHealth"

    $Unhealthy = $SysvolReport | Where-Object { $_.State -notin @("Normal") }
    if ($Unhealthy) {
        Write-WarningMessage "$($Unhealthy.Count) DC(s) not reporting a Normal SYSVOL replication state."
    }

}
catch {
    Write-ErrorMessage "Failed to collect SYSVOL / DFSR Health: $($_.Exception.Message)"
}
