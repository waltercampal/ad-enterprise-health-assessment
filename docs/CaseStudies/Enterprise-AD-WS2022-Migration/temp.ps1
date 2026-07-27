$Forest = Get-ADForest

foreach ($Domain in $Forest.Domains) {
    Get-ADDomainController -Server $Domain -Filter * |
    Select-Object HostName, Site, IPv4Address, OperatingSystem, IsGlobalCatalog
}