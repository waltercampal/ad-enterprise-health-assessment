<#
.SYNOPSIS
    Retrieves Active Directory Forest information.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.1.0
#>

Import-Module ActiveDirectory

$Forest = Get-ADForest

$Info = [PSCustomObject]@{

    ForestName = $Forest.Name
    ForestMode = $Forest.ForestMode
    RootDomain = $Forest.RootDomain
    Domains = ($Forest.Domains -join ", ")
    Sites = ($Forest.Sites -join ", ")
    GlobalCatalogs = ($Forest.GlobalCatalogs.Count)
    UPNSuffixes = ($Forest.UPNSuffixes -join ", ")

}

$Info

$Info |
Export-Csv `
-Path ".\reports\ForestInformation.csv" `
-NoTypeInformation `
-Encoding UTF8

Write-Host ""
Write-Host "Forest information exported successfully." -ForegroundColor Green
