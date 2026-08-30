<#
.SYNOPSIS
    Assesses basic Microsoft Entra ID (Azure AD) tenant health.

.DESCRIPTION
    Connects to Microsoft Graph and reports tenant-level information:
    organization name, total user count, hybrid (synced) vs cloud-only
    user counts, and Global Administrator count.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.1.0
#>

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Collecting Entra ID Assessment..."

if (!(Test-RequiredModule -ModuleName Microsoft.Graph.Authentication)) { return }

try {

    Connect-MgGraph -Scopes "Organization.Read.All", "User.Read.All", "RoleManagement.Read.Directory" -NoWelcome -ErrorAction Stop

    $Org = Get-MgOrganization

    $Users = Get-MgUser -All -Property Id, OnPremisesSyncEnabled, AccountEnabled
    $SyncedUsers = $Users | Where-Object { $_.OnPremisesSyncEnabled -eq $true }
    $CloudOnlyUsers = $Users | Where-Object { $_.OnPremisesSyncEnabled -ne $true }

    $GlobalAdminRole = Get-MgDirectoryRole -Filter "displayName eq 'Global Administrator'"
    $GlobalAdmins = if ($GlobalAdminRole) {
        Get-MgDirectoryRoleMember -DirectoryRoleId $GlobalAdminRole.Id
    }
    else {
        @()
    }

    $Info = [PSCustomObject]@{

        TenantName        = $Org.DisplayName
        TenantId          = $Org.Id
        TotalUsers        = ($Users | Measure-Object).Count
        SyncedUsers       = ($SyncedUsers | Measure-Object).Count
        CloudOnlyUsers    = ($CloudOnlyUsers | Measure-Object).Count
        GlobalAdminCount  = ($GlobalAdmins | Measure-Object).Count

    }

    $Info | Format-List

    Export-AssessmentCsv -Data $Info -Name "EntraIdAssessment"

    if ($Info.GlobalAdminCount -gt 5) {
        Write-WarningMessage "$($Info.GlobalAdminCount) Global Administrators assigned — review for least privilege."
    }

}
catch {
    Write-ErrorMessage "Failed to collect Entra ID Assessment: $($_.Exception.Message)"
}
finally {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}
