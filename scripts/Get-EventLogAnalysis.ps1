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

.PARAMETER Credential
    Optional alternate credential to query every domain/DC with. When
    supplied, this remotes into each DC via PowerShell remoting (WinRM)
    and runs Get-WinEvent there, rather than using Get-WinEvent's own
    -ComputerName/-Credential combination directly.

.VERSION
    0.3.0
#>

param(
    [PSCredential]$Credential
)

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Collecting Event Log Analysis (last 24 hours)..."

if (!(Test-RequiredModule -ModuleName ActiveDirectory)) { return }

try {

    $DomainControllers = Get-ForestDomainControllers -Credential $Credential
    $LogNames = @("System", "Application", "Directory Service")
    $Since = (Get-Date).AddHours(-24)

    $EventReport = foreach ($DC in $DomainControllers) {

        # Get-WinEvent -ComputerName combined with -Credential goes through
        # the legacy RPC-based Event Log remoting protocol instead of WinRM,
        # which can hang for minutes per unreachable server on a firewalled
        # network (confirmed against a real environment). Go through
        # Invoke-Command (WinRM, same reliable mechanism used elsewhere in
        # this toolkit) instead when a credential is supplied - one session
        # per DC, reused across all 3 logs.
        $Session = $null

        if ($Credential) {
            try {
                $Session = New-PSSession -ComputerName $DC.HostName -Credential $Credential -ErrorAction Stop
            }
            catch {
                Write-WarningMessage "Could not open a PS session to $($DC.HostName): $($_.Exception.Message)"
            }
        }

        foreach ($LogName in $LogNames) {

            try {

                if ($Credential) {
                    if (!$Session) { throw "No PS session available for $($DC.HostName)." }

                    $Events = Invoke-Command -Session $Session -ErrorAction Stop -ScriptBlock {
                        param($LogName, $Since)
                        Get-WinEvent -FilterHashtable @{
                            LogName   = $LogName
                            Level     = 1, 2 # Critical, Error
                            StartTime = $Since
                        } -ErrorAction Stop
                    } -ArgumentList $LogName, $Since
                }
                else {
                    $Events = Get-WinEvent -ComputerName $DC.HostName -ErrorAction Stop -FilterHashtable @{
                        LogName   = $LogName
                        Level     = 1, 2 # Critical, Error
                        StartTime = $Since
                    }
                }

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
                # Get-WinEvent throws when a FilterHashtable simply matches
                # nothing, or when the log doesn't exist on this DC - neither
                # is a real failure. When the exception traveled back through
                # Invoke-Command its .NET type isn't always preserved, so
                # fall back to matching on the message text too.
                if ($_.Exception.Message -match "No events were found" -or $_.Exception.Message -match "no such log") {
                    [PSCustomObject]@{
                        Server      = $DC.HostName
                        LogName     = $LogName
                        ErrorCount  = 0
                    }
                }
                else {
                    Write-WarningMessage "Could not query '$LogName' on $($DC.HostName): $($_.Exception.Message)"
                }
            }

        }

        if ($Session) { Remove-PSSession $Session -ErrorAction SilentlyContinue }

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
