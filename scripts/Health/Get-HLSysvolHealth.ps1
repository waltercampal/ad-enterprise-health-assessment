<#
.SYNOPSIS
    Retrieves SYSVOL / DFSR health: FRS-to-DFSR migration state per domain and
    SYSVOL share accessibility per Domain Controller.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    1.0.0
#>

function Get-HLSysvolHealth {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$DomainControllers,

        [System.Management.Automation.PSCredential]$Credential
    )

    $Results = @()
    $CmdSplat = if ($Credential) { @{ Credential = $Credential } } else { @{} }

    #--------------------------------------------------
    # FRS -> DFSR migration state (one check per domain)
    #--------------------------------------------------

    $DomainGroups = $DomainControllers | Group-Object -Property Domain

    foreach ($DomainGroup in $DomainGroups) {

        $Domain = $DomainGroup.Name
        $ProbeDC = $DomainGroup.Group | Select-Object -First 1

        Write-Verbose "Checking SYSVOL replication technology for $Domain via $($ProbeDC.HostName)"

        try {
            $MigrationState = Invoke-Command -ComputerName $ProbeDC.HostName @CmdSplat {
                dfsrmig /getglobalstate
            } -ErrorAction Stop

            $StateText = ($MigrationState -join ' ')

            if ($StateText -match 'Eliminated') {
                $Results += New-HealthResult `
                    -Category "SYSVOL" `
                    -Check "SYSVOL Replication Technology" `
                    -Target $Domain `
                    -Status Healthy `
                    -Severity Info `
                    -Message "dfsrmig migration state: Eliminated. SYSVOL is fully migrated to DFSR."
            }
            else {
                $Results += New-HealthResult `
                    -Category "SYSVOL" `
                    -Check "SYSVOL Replication Technology" `
                    -Target $Domain `
                    -Status Warning `
                    -Severity High `
                    -Message "dfsrmig migration state is not 'Eliminated': $StateText" `
                    -Recommendation "Complete the FRS to DFSR migration (dfsrmig /setglobalstate 3) before introducing Windows Server 2022 Domain Controllers. Windows Server 2022 does not support FRS."
            }
        }
        catch {
            $Results += New-HealthResult `
                -Category "SYSVOL" `
                -Check "SYSVOL Replication Technology" `
                -Target $Domain `
                -Status Warning `
                -Severity Medium `
                -Message $_.Exception.Message `
                -Recommendation "Verify WinRM/connectivity to $($ProbeDC.HostName) and re-run dfsrmig /getglobalstate manually."
        }
    }

    #--------------------------------------------------
    # SYSVOL share accessibility (per Domain Controller)
    #--------------------------------------------------

    foreach ($DC in $DomainControllers) {

        Write-Verbose "Checking SYSVOL share on $($DC.HostName)"

        $SysvolPath = "\\$($DC.HostName)\SYSVOL"

        try {
            $IsAccessible = $false

            if ($Credential) {
                $DriveName = "ADEHAT_$([guid]::NewGuid().ToString('N').Substring(0,8))"
                $Drive = New-PSDrive -Name $DriveName -PSProvider FileSystem -Root $SysvolPath -Credential $Credential -ErrorAction Stop
                $IsAccessible = $true
                Remove-PSDrive -Name $DriveName -Force -ErrorAction SilentlyContinue
            }
            else {
                $IsAccessible = Test-Path -Path $SysvolPath -ErrorAction Stop
            }

            if ($IsAccessible) {
                $Results += New-HealthResult `
                    -Category "SYSVOL" `
                    -Check "SYSVOL Share Accessibility" `
                    -Target $DC.HostName `
                    -Status Healthy `
                    -Severity Info `
                    -Message "$SysvolPath is accessible."
            }
            else {
                $Results += New-HealthResult `
                    -Category "SYSVOL" `
                    -Check "SYSVOL Share Accessibility" `
                    -Target $DC.HostName `
                    -Status Critical `
                    -Severity High `
                    -Message "$SysvolPath did not respond." `
                    -Recommendation "Verify the DFSR/NtFrs service and the SYSVOL share on this Domain Controller. Do not point clients at this DC for logon scripts or GPO delivery until resolved."
            }
        }
        catch {
            $Results += New-HealthResult `
                -Category "SYSVOL" `
                -Check "SYSVOL Share Accessibility" `
                -Target $DC.HostName `
                -Status Critical `
                -Severity High `
                -Message $_.Exception.Message `
                -Recommendation "Verify connectivity and the SYSVOL share on this Domain Controller."
        }
    }

    return $Results
}
