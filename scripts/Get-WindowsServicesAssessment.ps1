<#
.SYNOPSIS
    Checks the status of critical Windows services on each Domain Controller.

.DESCRIPTION
    Verifies that core AD-related services (NTDS, DNS, Netlogon, KDC, W32Time,
    DFSR) are running and set to start automatically on every Domain Controller.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.1.0
#>

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Collecting Windows Services Assessment..."

if (!(Test-RequiredModule -ModuleName ActiveDirectory)) { return }

try {

    $DomainControllers = Get-ADDomainController -Filter *
    $CriticalServices = @("NTDS", "DNS", "Netlogon", "Kdc", "W32Time", "DFSR")

    $ServiceReport = foreach ($DC in $DomainControllers) {

        foreach ($ServiceName in $CriticalServices) {

            try {

                $Service = Get-Service -ComputerName $DC.HostName -Name $ServiceName -ErrorAction Stop

                [PSCustomObject]@{
                    Server      = $DC.HostName
                    ServiceName = $ServiceName
                    Status      = $Service.Status
                    StartType   = $Service.StartType
                    Healthy     = ($Service.Status -eq "Running" -and $Service.StartType -eq "Automatic")
                }

            }
            catch {
                [PSCustomObject]@{
                    Server      = $DC.HostName
                    ServiceName = $ServiceName
                    Status      = "Not Found"
                    StartType   = "N/A"
                    Healthy     = $false
                }
            }

        }

    }

    $ServiceReport | Format-Table -AutoSize

    Export-AssessmentCsv -Data $ServiceReport -Name "WindowsServices"

    $Unhealthy = $ServiceReport | Where-Object { -not $_.Healthy }
    if ($Unhealthy) {
        Write-WarningMessage "$($Unhealthy.Count) critical service instance(s) not running/automatic."
    }
    else {
        Write-Success "All critical services running and set to Automatic."
    }

}
catch {
    Write-ErrorMessage "Failed to collect Windows Services Assessment: $($_.Exception.Message)"
}
