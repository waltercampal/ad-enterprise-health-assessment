<#
.SYNOPSIS
    Runs a basic Active Directory security baseline check.

.DESCRIPTION
    Reviews common security indicators: domain password policy, krbtgt
    account age, Domain Admins membership, accounts with Kerberos
    delegation enabled, and stale/never-expiring passwords.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.1.0
#>

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Running Security Baseline checks..."

if (!(Test-RequiredModule -ModuleName ActiveDirectory)) { return }

try {

    $Findings = @()

    # Password policy
    $PasswordPolicy = Get-ADDefaultDomainPasswordPolicy

    $Findings += [PSCustomObject]@{
        Check    = "Minimum Password Length"
        Value    = $PasswordPolicy.MinPasswordLength
        Severity = if ($PasswordPolicy.MinPasswordLength -lt 12) { "Warning" } else { "OK" }
    }

    $Findings += [PSCustomObject]@{
        Check    = "Password Complexity Enabled"
        Value    = $PasswordPolicy.ComplexityEnabled
        Severity = if ($PasswordPolicy.ComplexityEnabled) { "OK" } else { "Warning" }
    }

    # krbtgt account age
    $Krbtgt = Get-ADUser -Identity "krbtgt" -Properties PasswordLastSet
    $KrbtgtAgeDays = (New-TimeSpan -Start $Krbtgt.PasswordLastSet -End (Get-Date)).Days

    $Findings += [PSCustomObject]@{
        Check    = "krbtgt Password Age (days)"
        Value    = $KrbtgtAgeDays
        Severity = if ($KrbtgtAgeDays -gt 180) { "Warning" } else { "OK" }
    }

    # Domain Admins membership
    $DomainAdmins = Get-ADGroupMember -Identity "Domain Admins" -Recursive

    $Findings += [PSCustomObject]@{
        Check    = "Domain Admins Member Count"
        Value    = ($DomainAdmins | Measure-Object).Count
        Severity = if (($DomainAdmins | Measure-Object).Count -gt 5) { "Warning" } else { "OK" }
    }

    # Accounts with unconstrained Kerberos delegation
    $DelegationAccounts = Get-ADObject -Filter { TrustedForDelegation -eq $true -and ObjectClass -ne "computer" } -Properties TrustedForDelegation

    $Findings += [PSCustomObject]@{
        Check    = "Non-Computer Accounts with Unconstrained Delegation"
        Value    = ($DelegationAccounts | Measure-Object).Count
        Severity = if (($DelegationAccounts | Measure-Object).Count -gt 0) { "Warning" } else { "OK" }
    }

    # Passwords that never expire
    $NeverExpire = Get-ADUser -Filter { PasswordNeverExpires -eq $true -and Enabled -eq $true } -Properties PasswordNeverExpires

    $Findings += [PSCustomObject]@{
        Check    = "Enabled Accounts with Non-Expiring Passwords"
        Value    = ($NeverExpire | Measure-Object).Count
        Severity = if (($NeverExpire | Measure-Object).Count -gt 0) { "Warning" } else { "OK" }
    }

    # Stale accounts (no logon in 90+ days)
    $StaleThreshold = (Get-Date).AddDays(-90)
    $StaleAccounts = Get-ADUser -Filter { LastLogonTimeStamp -lt $StaleThreshold -and Enabled -eq $true } -Properties LastLogonTimeStamp

    $Findings += [PSCustomObject]@{
        Check    = "Enabled Accounts Inactive 90+ Days"
        Value    = ($StaleAccounts | Measure-Object).Count
        Severity = if (($StaleAccounts | Measure-Object).Count -gt 0) { "Warning" } else { "OK" }
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
