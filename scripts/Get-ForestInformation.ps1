<#
.SYNOPSIS
    Retrieves Active Directory Forest information.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.2.0
#>

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Collecting Forest information..."

if (!(Test-RequiredModule -ModuleName ActiveDirectory)) { return }

try {

    $Forest = Get-ADForest

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
