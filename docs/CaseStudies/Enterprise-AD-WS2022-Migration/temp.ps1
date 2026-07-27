$DCs = foreach ($Domain in (Get-ADForest).Domains) {
    Get-ADDomainController -Server $Domain -Filter *
}

$DCs |
Group-Object OperatingSystem |
Select-Object Name,Count


($DCs | Where-Object IsGlobalCatalog).Count

($DCs | Where-Object IsGlobalCatalog).Count

repadmin /replsummary