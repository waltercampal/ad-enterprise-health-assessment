<#
.SYNOPSIS
    Checks the status of critical Windows services on each Domain Controller.

.DESCRIPTION
    Verifies that core AD-related services (NTDS, DNS, Netlogon, KDC, W32Time,
    DFSR) are running and set to start automatically on every Domain Controller.

.AUTHOR
    Walter Campal
    Horizon Labs

.PARAMETER Credential
    Optional alternate credential to query every domain/DC with. Get-Service
    doesn't support -Credential at all, so this uses Get-CimInstance
    (Win32_Service) instead when a credential is supplied.

.VERSION
    0.2.0
#>

param(
    [PSCredential]$Credential
)

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Collecting Windows Services Assessment..."

if (!(Test-RequiredModule -ModuleName ActiveDirectory)) { return }

try {

    $DomainControllers = Get-ForestDomainControllers -Credential $Credential
    $CriticalServices = @("NTDS", "DNS", "Netlogon", "Kdc", "W32Time", "DFSR")

    $ServiceReport = foreach ($DC in $DomainControllers) {

        foreach ($ServiceName in $CriticalServices) {

            try {

                if ($Credential) {
                    # Get-Service has no -Credential parameter; Win32_Service
                    # reports Started/Stopped and Auto/Manual/Disabled instead
                    # of Get-Service's Running/Stopped and Automatic/Manual.
                    $Svc = Get-CimInstance -ComputerName $DC.HostName -ClassName Win32_Service `
                        -Filter "Name='$ServiceName'" -Credential $Credential -ErrorAction Stop

                    if (!$Svc) { throw "Service '$ServiceName' not found." }

                    $Status = if ($Svc.State -eq "Running") { "Running" } else { "Stopped" }
                    $StartType = if ($Svc.StartMode -eq "Auto") { "Automatic" } else { $Svc.StartMode }
                }
                else {
                    $Svc = Get-Service -ComputerName $DC.HostName -Name $ServiceName -ErrorAction Stop
                    $Status = $Svc.Status
                    $StartType = $Svc.StartType
                }

                [PSCustomObject]@{
                    Server      = $DC.HostName
                    ServiceName = $ServiceName
                    Status      = $Status
                    StartType   = $StartType
                    Healthy     = ($Status -eq "Running" -and $StartType -eq "Automatic")
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
