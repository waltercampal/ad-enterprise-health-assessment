<#
.SYNOPSIS
    Retrieves Windows Time Service health for all Domain Controllers in the forest.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    1.1.0
#>

function Get-HLTimeHealth {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$DomainControllers,

        [System.Management.Automation.PSCredential]$Credential
    )

    $Results = @()
    $CmdSplat = if ($Credential) { @{ Credential = $Credential } } else { @{} }

    foreach ($DC in $DomainControllers) {

        Write-Verbose "Checking Time Service on $($DC.HostName)"

        #--------------------------------------------------
        # W32Time Service (CIM - works across PowerShell versions,
        # unlike Get-Service -ComputerName which was removed in
        # PowerShell 7+)
        #--------------------------------------------------

        try {

            $Service = Get-HLCimInstance `
                -ComputerName $DC.HostName `
                -ClassName Win32_Service `
                -Filter "Name='W32Time'" `
                -Credential $Credential

            $IsRunning = $Service.State -eq 'Running'

            $Results += New-HealthResult `
                -Category "Time" `
                -Check "Windows Time Service" `
                -Target $DC.HostName `
                -Status $(if ($IsRunning) { "Healthy" } else { "Critical" }) `
                -Severity $(if ($IsRunning) { "Info" } else { "High" }) `
                -Message "Service Status: $($Service.State)" `
                -Recommendation $(if (-not $IsRunning) { "Start the Windows Time Service on this Domain Controller." } else { "" })

        }
        catch {

            $Results += New-HealthResult `
                -Category "Time" `
                -Check "Windows Time Service" `
                -Target $DC.HostName `
                -Status "Warning" `
                -Severity "Medium" `
                -Message $_.Exception.Message `
                -Recommendation "Verify connectivity/CIM access to this Domain Controller."
        }

        #--------------------------------------------------
        # Time Source
        #--------------------------------------------------

        try {

            $Source = Invoke-Command -ComputerName $DC.HostName @CmdSplat {
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
