<#
.SYNOPSIS
    Retrieves Active Directory Forest information.

.AUTHOR
    Walter Campal
    Horizon Labs

.PARAMETER Credential
    Optional alternate credential to query the forest with.

.VERSION
    0.3.0
#>

param(
    [PSCredential]$Credential
)

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Collecting Forest information..."

if (!(Test-RequiredModule -ModuleName ActiveDirectory)) { return }

try {

    $AdParams = @{ ErrorAction = "Stop" }
    if ($Credential) { $AdParams["Credential"] = $Credential }

    $Forest = Get-ADForest @AdParams

    $Info = [PSCustomObject]@{

        ForestName     = $Forest.Name
        ForestMode     = $Forest.ForestMode
        RootDomain     = $Forest.RootDomain
        Domains        = ($Forest.Domains -join ", ")
        Sites          = ($Forest.Sites -join ", ")
        GlobalCatalogs = ($Forest.GlobalCatalogs.Count)
        UPNSuffixes    = ($Forest.UPNSuffixes -join ", ")

    }

    $Info | Format-List

    Export-AssessmentCsv -Data $Info -Name "ForestInformation"

}
catch {
    Write-ErrorMessage "Failed to collect Forest information: $($_.Exception.Message)"
}
