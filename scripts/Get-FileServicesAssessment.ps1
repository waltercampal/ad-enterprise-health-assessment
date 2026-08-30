<#
.SYNOPSIS
    Assesses file share configuration and disk capacity on Domain Controllers.

.DESCRIPTION
    Collects SMB share inventory (including default/administrative shares)
    and logical disk free space per Domain Controller, flagging volumes
    running low on space.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.1.0
#>

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Collecting File Services Assessment..."

if (!(Test-RequiredModule -ModuleName ActiveDirectory)) { return }

try {

    $DomainControllers = Get-ADDomainController -Filter *
    $ShareReport = @()
    $DiskReport = @()

    foreach ($DC in $DomainControllers) {

        try {
            $Shares = Get-SmbShare -CimSession $DC.HostName -ErrorAction Stop
            $ShareReport += foreach ($Share in $Shares) {
                [PSCustomObject]@{
                    Server      = $DC.HostName
                    ShareName   = $Share.Name
                    Path        = $Share.Path
                    Description = $Share.Description
                }
            }
        }
        catch {
            Write-WarningMessage "Could not query SMB shares on $($DC.HostName): $($_.Exception.Message)"
        }

        try {
            $Disks = Get-CimInstance -ComputerName $DC.HostName -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop
            $DiskReport += foreach ($Disk in $Disks) {
                $FreePercent = if ($Disk.Size -gt 0) { [math]::Round(($Disk.FreeSpace / $Disk.Size) * 100, 1) } else { 0 }
                [PSCustomObject]@{
                    Server         = $DC.HostName
                    Drive          = $Disk.DeviceID
                    SizeGB         = [math]::Round($Disk.Size / 1GB, 1)
                    FreeSpaceGB    = [math]::Round($Disk.FreeSpace / 1GB, 1)
                    FreePercent    = $FreePercent
                }
            }
        }
        catch {
            Write-WarningMessage "Could not query disk information on $($DC.HostName): $($_.Exception.Message)"
        }

    }

    $ShareReport | Format-Table -AutoSize
    $DiskReport | Format-Table -AutoSize

    Export-AssessmentCsv -Data $ShareReport -Name "FileShares"
    Export-AssessmentCsv -Data $DiskReport -Name "DiskCapacity"

    $LowDisk = $DiskReport | Where-Object { $_.FreePercent -lt 15 }
    if ($LowDisk) {
        Write-WarningMessage "$($LowDisk.Count) volume(s) below 15% free space."
    }

}
catch {
    Write-ErrorMessage "Failed to collect File Services Assessment: $($_.Exception.Message)"
}
