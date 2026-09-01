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

    # Reuse an existing Graph session (e.g. from another module run in the same
    # orchestrator) instead of forcing a second interactive sign-in.
    # -UseDeviceCode: see Get-EntraIdAssessment.ps1 for why.
    if (!(Get-MgContext)) {
        Connect-MgGraph -Scopes "Policy.Read.All" -UseDeviceCode -NoWelcome -ErrorAction Stop
    }

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
# The Graph session is intentionally left connected so other modules in the
# same run can reuse it. Run Disconnect-MgGraph yourself when you're done.
