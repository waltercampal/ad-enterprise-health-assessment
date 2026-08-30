<#
.SYNOPSIS
    Summarizes recent Error and Critical events on each Domain Controller.

.DESCRIPTION
    Queries the System, Application, and Directory Service event logs on
    each Domain Controller for Error/Critical entries in the last 24 hours,
    producing a per-server, per-log summary count to spot emerging issues.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.1.0
#>

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Collecting Event Log Analysis (last 24 hours)..."

if (!(Test-RequiredModule -ModuleName ActiveDirectory)) { return }

try {

    $DomainControllers = Get-ForestDomainControllers
    $LogNames = @("System", "Application", "Directory Service")
    $Since = (Get-Date).AddHours(-24)

    $EventReport = foreach ($DC in $DomainControllers) {

        foreach ($LogName in $LogNames) {

            try {

                $Events = Get-WinEvent -ComputerName $DC.HostName -FilterHashtable @{
                    LogName   = $LogName
                    Level     = 1, 2 # Critical, Error
                    StartTime = $Since
                } -ErrorAction Stop

                [PSCustomObject]@{
                    Server      = $DC.HostName
                    LogName     = $LogName
                    ErrorCount  = ($Events | Measure-Object).Count
                }

            }
            catch [System.Diagnostics.Eventing.Reader.EventLogNotFoundException] {
                [PSCustomObject]@{
                    Server      = $DC.HostName
                    LogName     = $LogName
                    ErrorCount  = 0
                }
            }
            catch {
                Write-WarningMessage "Could not query '$LogName' on $($DC.HostName): $($_.Exception.Message)"
            }

        }

    }

    $EventReport | Format-Table -AutoSize

    Export-AssessmentCsv -Data $EventReport -Name "EventLogAnalysis"

    $Noisy = $EventReport | Where-Object { $_.ErrorCount -gt 20 }
    if ($Noisy) {
        Write-WarningMessage "$($Noisy.Count) server/log combination(s) with 20+ errors in the last 24h."
    }

}
catch {
    Write-ErrorMessage "Failed to collect Event Log Analysis: $($_.Exception.Message)"
}
