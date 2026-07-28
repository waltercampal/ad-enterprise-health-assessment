<#
.SYNOPSIS
    Retrieves recent Critical/Error events from the Directory Service, DNS
    Server and DFS Replication logs on each Domain Controller.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    1.0.0
#>

function Get-HLEventLogHealth {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$DomainControllers,

        [int]$Hours = 24
    )

    $Results = @()

    $LogsToCheck = @(
        @{ LogName = 'Directory Service';  Check = 'Directory Service Log (last {0}h)' -f $Hours }
        @{ LogName = 'DNS Server';         Check = 'DNS Server Log (last {0}h)' -f $Hours }
        @{ LogName = 'DFS Replication';    Check = 'DFS Replication Log (last {0}h)' -f $Hours }
    )

    $Since = (Get-Date).AddHours(-$Hours)

    foreach ($DC in $DomainControllers) {

        foreach ($Log in $LogsToCheck) {

            Write-Verbose "Checking $($Log.LogName) log on $($DC.HostName)"

            try {
                $Events = Get-WinEvent -ComputerName $DC.HostName -FilterHashtable @{
                    LogName   = $Log.LogName
                    Level     = 1, 2, 3 # Critical, Error, Warning
                    StartTime = $Since
                } -ErrorAction Stop

                $Critical = @($Events | Where-Object Level -in 1, 2)
                $Warning  = @($Events | Where-Object Level -eq 3)

                if ($Critical.Count -gt 0) {
                    $Results += New-HealthResult `
                        -Category "EventLog" `
                        -Check $Log.Check `
                        -Target $DC.HostName `
                        -Status Critical `
                        -Severity High `
                        -Message "$($Critical.Count) Critical/Error event(s) in the last $Hours hours (most recent: Event ID $($Critical[0].Id))." `
                        -Recommendation "Review the $($Log.LogName) log on this Domain Controller before proceeding with migration steps that depend on it."
                }
                elseif ($Warning.Count -gt 0) {
                    $Results += New-HealthResult `
                        -Category "EventLog" `
                        -Check $Log.Check `
                        -Target $DC.HostName `
                        -Status Warning `
                        -Severity Medium `
                        -Message "$($Warning.Count) Warning event(s) in the last $Hours hours (most recent: Event ID $($Warning[0].Id))." `
                        -Recommendation "Review the $($Log.LogName) log on this Domain Controller."
                }
                else {
                    $Results += New-HealthResult `
                        -Category "EventLog" `
                        -Check $Log.Check `
                        -Target $DC.HostName `
                        -Status Healthy `
                        -Severity Info `
                        -Message "No Critical or Error events found."
                }
            }
            catch [Exception] {

                if ($_.Exception.Message -match 'No events were found') {
                    $Results += New-HealthResult `
                        -Category "EventLog" `
                        -Check $Log.Check `
                        -Target $DC.HostName `
                        -Status Healthy `
                        -Severity Info `
                        -Message "No Critical or Error events found."
                }
                else {
                    $Results += New-HealthResult `
                        -Category "EventLog" `
                        -Check $Log.Check `
                        -Target $DC.HostName `
                        -Status Warning `
                        -Severity Medium `
                        -Message $_.Exception.Message `
                        -Recommendation "Verify connectivity and remote event log access (Remote Event Log Management firewall rule) on this Domain Controller."
                }
            }
        }
    }

    return $Results
}
