<#
.SYNOPSIS
    Retrieves Active Directory Forest information.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.2.0
#>


Import-Module ActiveDirectory

$Forest = Get-ADForest

$ForestInfo = [PSCustomObject]@{

    ForestName         = $Forest.Name
    ForestMode         = $Forest.ForestMode
    RootDomain         = $Forest.RootDomain

    DomainCount        = $Forest.Domains.Count
    Domains            = $Forest.Domains

    SiteCount          = $Forest.Sites.Count
    Sites              = $Forest.Sites

    GlobalCatalogCount = $Forest.GlobalCatalogs.Count
    GlobalCatalogs     = $Forest.GlobalCatalogs

    UPNSuffixes        = $Forest.UPNSuffixes

    SchemaMaster       = $Forest.SchemaMaster
    DomainNamingMaster = $Forest.DomainNamingMaster

}

return $ForestInfo