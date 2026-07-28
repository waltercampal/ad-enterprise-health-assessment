<#
.SYNOPSIS
    Retrieves a basic Active Directory security baseline: SMBv1 exposure per
    Domain Controller, LAPS deployment, and privileged account hygiene.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    1.0.0
#>

function Get-HLSecurityBaseline {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$DomainControllers,

        [Parameter(Mandatory)]
        [array]$Domains
    )

    $Results = @()

    #--------------------------------------------------
    # SMBv1 protocol (per Domain Controller)
    #--------------------------------------------------

    foreach ($DC in $DomainControllers) {

        Write-Verbose "Checking SMBv1 on $($DC.HostName)"

        try {
            $Smb1 = Invoke-Command -ComputerName $DC.HostName {
                (Get-SmbServerConfiguration).EnableSMB1Protocol
            } -ErrorAction Stop

            if ($Smb1) {
                $Results += New-HealthResult `
                    -Category "Security" `
                    -Check "SMBv1 Protocol" `
                    -Target $DC.HostName `
                    -Status Critical `
                    -Severity High `
                    -Message "SMBv1 protocol is still enabled." `
                    -Recommendation "Disable the FS-SMB1 Windows feature. SMBv1 is a known attack vector (WannaCry/EternalBlue) and must be removed before migrating this Domain Controller."
            }
            else {
                $Results += New-HealthResult `
                    -Category "Security" `
                    -Check "SMBv1 Protocol" `
                    -Target $DC.HostName `
                    -Status Healthy `
                    -Severity Info `
                    -Message "SMBv1 is disabled."
            }
        }
        catch {
            $Results += New-HealthResult `
                -Category "Security" `
                -Check "SMBv1 Protocol" `
                -Target $DC.HostName `
                -Status Warning `
                -Severity Medium `
                -Message $_.Exception.Message `
                -Recommendation "Verify WinRM/connectivity to this Domain Controller and re-run this check."
        }
    }

    #--------------------------------------------------
    # LAPS deployment (forest-wide, schema check)
    #--------------------------------------------------

    try {
        $Schema = (Get-ADRootDSE -ErrorAction Stop).schemaNamingContext

        $LapsAttribute = Get-ADObject `
            -SearchBase $Schema `
            -Filter { lDAPDisplayName -eq "ms-Mcs-AdmPwd" } `
            -ErrorAction Stop

        if ($LapsAttribute) {
            $Results += New-HealthResult `
                -Category "Security" `
                -Check "LAPS Deployment" `
                -Target "Forest" `
                -Status Healthy `
                -Severity Info `
                -Message "The ms-Mcs-AdmPwd schema attribute is present."
        }
        else {
            $Results += New-HealthResult `
                -Category "Security" `
                -Check "LAPS Deployment" `
                -Target "Forest" `
                -Status Warning `
                -Severity Medium `
                -Message "The ms-Mcs-AdmPwd schema attribute was not found." `
                -Recommendation "Deploy Local Administrator Password Solution before decommissioning legacy Domain Controllers to avoid re-using shared local admin passwords on new servers."
        }
    }
    catch {
        $Results += New-HealthResult `
            -Category "Security" `
            -Check "LAPS Deployment" `
            -Target "Forest" `
            -Status Warning `
            -Severity Medium `
            -Message $_.Exception.Message `
            -Recommendation "Verify schema read access and re-run this check."
    }

    #--------------------------------------------------
    # Privileged account hygiene (per domain)
    #--------------------------------------------------

    foreach ($Domain in $Domains) {

        Write-Verbose "Checking privileged accounts on $($Domain.DomainName)"

        try {
            $DomainAdmins = Get-ADGroupMember `
                -Identity "Domain Admins" `
                -Server $Domain.DomainName `
                -Recursive `
                -ErrorAction Stop |
                Where-Object { $_.objectClass -eq 'user' } |
                Get-ADUser -Properties PasswordNeverExpires, DoesNotRequirePreAuth -Server $Domain.DomainName

            $NeverExpires = $DomainAdmins | Where-Object PasswordNeverExpires

            if ($NeverExpires) {
                $Results += New-HealthResult `
                    -Category "Security" `
                    -Check "Privileged Account Hygiene" `
                    -Target "Domain Admins ($($Domain.DomainName))" `
                    -Status Warning `
                    -Severity Medium `
                    -Message "$($NeverExpires.Count) account(s) in Domain Admins have PasswordNeverExpires enabled." `
                    -Recommendation "Review these accounts; rotate passwords and enable expiration, or move service accounts to a group Managed Service Account (gMSA)."
            }

            $NoPreAuth = $DomainAdmins | Where-Object DoesNotRequirePreAuth

            foreach ($Account in $NoPreAuth) {
                $Results += New-HealthResult `
                    -Category "Security" `
                    -Check "Kerberos Pre-Authentication" `
                    -Target "$($Account.SamAccountName) ($($Domain.DomainName))" `
                    -Status Critical `
                    -Severity High `
                    -Message "Account does not require Kerberos pre-authentication (AS-REP roasting exposure)." `
                    -Recommendation "Enable Kerberos pre-authentication for this account or replace it with a group Managed Service Account (gMSA)."
            }
        }
        catch {
            $Results += New-HealthResult `
                -Category "Security" `
                -Check "Privileged Account Hygiene" `
                -Target $Domain.DomainName `
                -Status Warning `
                -Severity Medium `
                -Message $_.Exception.Message `
                -Recommendation "Verify connectivity to $($Domain.DomainName) and re-run this check."
        }
    }

    return $Results
}
