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

.PARAMETER Credential
    Optional alternate credential to query every domain/DC with.

.VERSION
    0.2.0
#>

param(
    [PSCredential]$Credential
)

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Collecting File Services Assessment..."

if (!(Test-RequiredModule -ModuleName ActiveDirectory)) { return }

try {

    $DomainControllers = Get-ForestDomainControllers -Credential $Credential
    $ShareReport = @()
    $DiskReport = @()

    foreach ($DC in $DomainControllers) {

        # One CimSession per DC, reused for both the share and disk queries
        # below. Get-CimInstance -ComputerName combined with -Credential is
        # unreliable across PowerShell/CIM versions ("A parameter cannot be
        # found that matches parameter name 'Credential'"); -CimSession is
        # the mechanism that actually works, confirmed against a real
        # environment where the -CimSession-based share query succeeded and
        # the -ComputerName/-Credential disk query failed on every server.
        $CimSession = $null

        try {
            if ($Credential) {
                $CimSession = New-CimSession -ComputerName $DC.HostName -Credential $Credential -ErrorAction Stop
            }
        }
        catch {
            Write-WarningMessage "Could not open a CIM session to $($DC.HostName): $($_.Exception.Message)"
        }

        try {
            $Shares = if ($CimSession) {
                Get-SmbShare -CimSession $CimSession -ErrorAction Stop
            }
            else {
                Get-SmbShare -CimSession $DC.HostName -ErrorAction Stop
            }
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
            $CimParams = @{ ClassName = "Win32_LogicalDisk"; Filter = "DriveType=3"; ErrorAction = "Stop" }
            if ($CimSession) { $CimParams["CimSession"] = $CimSession } else { $CimParams["ComputerName"] = $DC.HostName }

            $Disks = Get-CimInstance @CimParams
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
        finally {
            if ($CimSession) { Remove-CimSession $CimSession -ErrorAction SilentlyContinue }
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
