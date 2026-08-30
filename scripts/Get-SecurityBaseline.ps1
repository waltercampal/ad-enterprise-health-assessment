<#
.SYNOPSIS
    Runs a basic Active Directory security baseline check across every domain in the forest.

.DESCRIPTION
    For every domain in the forest, reviews common security indicators:
    domain password policy, krbtgt account age, Domain Admins membership,
    accounts with Kerberos delegation enabled, and stale/never-expiring
    passwords. Each finding is tagged with the domain it applies to, since
    these are domain-scoped checks (each domain has its own krbtgt, its
    own Domain Admins group, and its own password policy).

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.2.0
#>

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Running Security Baseline checks (all domains in the forest)..."

if (!(Test-RequiredModule -ModuleName ActiveDirectory)) { return }

try {

    $Findings = foreach ($DomainName in (Get-ForestDomains)) {

        try {

            # Password policy
            $PasswordPolicy = Get-ADDefaultDomainPasswordPolicy -Server $DomainName -ErrorAction Stop

            [PSCustomObject]@{
                Domain   = $DomainName
                Check    = "Minimum Password Length"
                Value    = $PasswordPolicy.MinPasswordLength
                Severity = if ($PasswordPolicy.MinPasswordLength -lt 12) { "Warning" } else { "OK" }
            }

            [PSCustomObject]@{
                Domain   = $DomainName
                Check    = "Password Complexity Enabled"
                Value    = $PasswordPolicy.ComplexityEnabled
                Severity = if ($PasswordPolicy.ComplexityEnabled) { "OK" } else { "Warning" }
            }

            # krbtgt account age
            $Krbtgt = Get-ADUser -Identity "krbtgt" -Server $DomainName -Properties PasswordLastSet
            $KrbtgtAgeDays = (New-TimeSpan -Start $Krbtgt.PasswordLastSet -End (Get-Date)).Days

            [PSCustomObject]@{
                Domain   = $DomainName
                Check    = "krbtgt Password Age (days)"
                Value    = $KrbtgtAgeDays
                Severity = if ($KrbtgtAgeDays -gt 180) { "Warning" } else { "OK" }
            }

            # Domain Admins membership
            $DomainAdmins = Get-ADGroupMember -Identity "Domain Admins" -Server $DomainName -Recursive

            [PSCustomObject]@{
                Domain   = $DomainName
                Check    = "Domain Admins Member Count"
                Value    = ($DomainAdmins | Measure-Object).Count
                Severity = if (($DomainAdmins | Measure-Object).Count -gt 5) { "Warning" } else { "OK" }
            }

            # Accounts with unconstrained Kerberos delegation
            $DelegationAccounts = Get-ADObject -Filter { TrustedForDelegation -eq $true -and ObjectClass -ne "computer" } -Server $DomainName -Properties TrustedForDelegation

            [PSCustomObject]@{
                Domain   = $DomainName
                Check    = "Non-Computer Accounts with Unconstrained Delegation"
                Value    = ($DelegationAccounts | Measure-Object).Count
                Severity = if (($DelegationAccounts | Measure-Object).Count -gt 0) { "Warning" } else { "OK" }
            }

            # Passwords that never expire
            $NeverExpire = Get-ADUser -Filter { PasswordNeverExpires -eq $true -and Enabled -eq $true } -Server $DomainName -Properties PasswordNeverExpires

            [PSCustomObject]@{
                Domain   = $DomainName
                Check    = "Enabled Accounts with Non-Expiring Passwords"
                Value    = ($NeverExpire | Measure-Object).Count
                Severity = if (($NeverExpire | Measure-Object).Count -gt 0) { "Warning" } else { "OK" }
            }

            # Stale accounts (no logon in 90+ days)
            $StaleThreshold = (Get-Date).AddDays(-90)
            $StaleAccounts = Get-ADUser -Filter { LastLogonTimeStamp -lt $StaleThreshold -and Enabled -eq $true } -Server $DomainName -Properties LastLogonTimeStamp

            [PSCustomObject]@{
                Domain   = $DomainName
                Check    = "Enabled Accounts Inactive 90+ Days"
                Value    = ($StaleAccounts | Measure-Object).Count
                Severity = if (($StaleAccounts | Measure-Object).Count -gt 0) { "Warning" } else { "OK" }
            }

        }
        catch {
            Write-WarningMessage "Could not run security baseline checks against domain '$DomainName': $($_.Exception.Message)"
        }

    }

    $Findings | Format-Table -AutoSize

    Export-AssessmentCsv -Data $Findings -Name "SecurityBaseline"

    $Warnings = $Findings | Where-Object { $_.Severity -eq "Warning" }
    if ($Warnings) {
        Write-WarningMessage "$($Warnings.Count) security baseline check(s) flagged for review."
    }
    else {
        Write-Success "All security baseline checks passed."
    }

}
catch {
    Write-ErrorMessage "Failed to run Security Baseline: $($_.Exception.Message)"
}
