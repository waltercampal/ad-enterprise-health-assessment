<#
.SYNOPSIS
    Reviews Microsoft Entra Conditional Access policies.

.DESCRIPTION
    Connects to Microsoft Graph and inventories all Conditional Access
    policies, their enabled state, and whether any policy is set to
    "report-only" (indicating it is not yet enforced).

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.1.0
#>

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Collecting Conditional Access Review..."

if (!(Test-RequiredModule -ModuleName Microsoft.Graph.Identity.SignIns)) { return }

try {

    Connect-MgGraph -Scopes "Policy.Read.All" -NoWelcome -ErrorAction Stop

    $Policies = Get-MgIdentityConditionalAccessPolicy

    $CAReport = foreach ($Policy in $Policies) {

        [PSCustomObject]@{

            Name        = $Policy.DisplayName
            State       = $Policy.State
            CreatedDate = $Policy.CreatedDateTime
            ModifiedDate = $Policy.ModifiedDateTime

        }

    }

    $CAReport | Format-Table -AutoSize

    Export-AssessmentCsv -Data $CAReport -Name "ConditionalAccessPolicies"

    $ReportOnly = $CAReport | Where-Object { $_.State -eq "enabledForReportingButNotEnforced" }
    $Disabled = $CAReport | Where-Object { $_.State -eq "disabled" }

    if ($ReportOnly) {
        Write-WarningMessage "$($ReportOnly.Count) policy(ies) in report-only mode (not enforced)."
    }
    if ($Disabled) {
        Write-WarningMessage "$($Disabled.Count) policy(ies) disabled."
    }

}
catch {
    Write-ErrorMessage "Failed to collect Conditional Access Review: $($_.Exception.Message)"
}
finally {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}
