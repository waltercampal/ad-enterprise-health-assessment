<#
.SYNOPSIS
    Retrieves Windows Server configuration health for Domain Controllers:
    operating system version and system drive free space.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    1.0.0
#>

function Get-HLServerConfig {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$DomainControllers
    )

    $Results = @()

    foreach ($DC in $DomainControllers) {

        Write-Verbose "Checking server configuration on $($DC.HostName)"

        #--------------------------------------------------
        # Operating System Version
        #--------------------------------------------------

        if ($DC.OperatingSystem -match '2022') {
            $Results += New-HealthResult `
                -Category "ServerConfig" `
                -Check "Operating System Version" `
                -Target $DC.HostName `
                -Status Healthy `
                -Severity Info `
                -Message "$($DC.OperatingSystem) - migration target already met."
        }
        else {
            $Results += New-HealthResult `
                -Category "ServerConfig" `
                -Check "Operating System Version" `
                -Target $DC.HostName `
                -Status Warning `
                -Severity Low `
                -Message "$($DC.OperatingSystem) - eligible for in-place retirement." `
                -Recommendation "Schedule replacement with a Windows Server 2022 Domain Controller as part of this migration."
        }

        #--------------------------------------------------
        # System Drive Free Space
        #--------------------------------------------------

        try {
            $Disk = Get-CimInstance `
                -ComputerName $DC.HostName `
                -ClassName Win32_LogicalDisk `
                -Filter "DeviceID='C:'" `
                -ErrorAction Stop

            $FreePercent = [math]::Round(($Disk.FreeSpace / $Disk.Size) * 100)

            if ($FreePercent -lt 10) {
                $Results += New-HealthResult `
                    -Category "ServerConfig" `
                    -Check "System Drive Free Space" `
                    -Target $DC.HostName `
                    -Status Critical `
                    -Severity High `
                    -Message "Only $FreePercent% free space on C:\ (NTDS/logs volume)." `
                    -Recommendation "Free up disk space or extend the volume immediately; low disk space risks database corruption and prevents safe DIT maintenance during migration."
            }
            elseif ($FreePercent -lt 20) {
                $Results += New-HealthResult `
                    -Category "ServerConfig" `
                    -Check "System Drive Free Space" `
                    -Target $DC.HostName `
                    -Status Warning `
                    -Severity Medium `
                    -Message "$FreePercent% free space on C:\." `
                    -Recommendation "Monitor and plan cleanup before promoting this Domain Controller's Windows Server 2022 replacement."
            }
            else {
                $Results += New-HealthResult `
                    -Category "ServerConfig" `
                    -Check "System Drive Free Space" `
                    -Target $DC.HostName `
                    -Status Healthy `
                    -Severity Info `
                    -Message "$FreePercent% free space on C:\."
            }
        }
        catch {
            $Results += New-HealthResult `
                -Category "ServerConfig" `
                -Check "System Drive Free Space" `
                -Target $DC.HostName `
                -Status Warning `
                -Severity Medium `
                -Message $_.Exception.Message `
                -Recommendation "Verify connectivity to this Domain Controller and re-run this check."
        }
    }

    return $Results
}
