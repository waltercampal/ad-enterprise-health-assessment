<#
.SYNOPSIS
    Retrieves Windows Time Service health for all Domain Controllers in the forest.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    1.0.0
#>

function Get-HLTimeHealth {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$DomainControllers
    )

    $Results = @()

    foreach ($DC in $DomainControllers) {

        Write-Verbose "Checking Time Service on $($DC.HostName)"

        #--------------------------------------------------
        # W32Time Service
        #--------------------------------------------------

        try {

            $Service = Get-Service `
                -ComputerName $DC.HostName `
                -Name W32Time `
                -ErrorAction Stop

            $Results += New-HealthResult `
                -Category "Time" `
                -Check "Windows Time Service" `
                -Target $DC.HostName `
                -Status $(if ($Service.Status -eq "Running") { "Healthy" } else { "Critical" }) `
                -Severity $(if ($Service.Status -eq "Running") { "Info" } else { "High" }) `
                -Message "Service Status: $($Service.Status)" `
                -Recommendation $(if ($Service.Status -ne "Running") { "Start the Windows Time Service on this Domain Controller." } else { "" })

        }
        catch {

            $Results += New-HealthResult `
                -Category "Time" `
                -Check "Windows Time Service" `
                -Target $DC.HostName `
                -Status "Critical" `
                -Severity "High" `
                -Message $_.Exception.Message `
                -Recommendation "Verify connectivity and the Windows Time Service on this Domain Controller."
        }

        #--------------------------------------------------
        # Time Source
        #--------------------------------------------------

        try {

            $Source = Invoke-Command -ComputerName $DC.HostName {
                w32tm /query /source
            } -ErrorAction Stop

            $Results += New-HealthResult `
                -Category "Time" `
                -Check "Time Source" `
                -Target $DC.HostName `
                -Status "Healthy" `
                -Message "Source: $($Source -join ' ')"

        }
        catch {

            $Results += New-HealthResult `
                -Category "Time" `
                -Check "Time Source" `
                -Target $DC.HostName `
                -Status "Warning" `
                -Severity "Medium" `
                -Message $_.Exception.Message `
                -Recommendation "Verify WinRM/connectivity to this Domain Controller and confirm its time source matches the domain hierarchy (PDC Emulator -> external NTP)."
        }

    }

    return $Results
}
