<#
.SYNOPSIS
    Retrieves Active Directory Domain information.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.1.0
#>

Import-Module ActiveDirectory

$Domain = Get-ADDomain

$Info = [PSCustomObject]@{

    DomainName = $Domain.DNSRoot
    NetBIOSName = $Domain.NetBIOSName
    DomainMode = $Domain.DomainMode
    DistinguishedName = $Domain.DistinguishedName
    ParentDomain = $Domain.ParentDomain
    PDCEmulator = $Domain.PDCEmulator
    RIDMaster = $Domain.RIDMaster
    InfrastructureMaster = $Domain.InfrastructureMaster

}

$Info

$Info |
Export-Csv `
-Path ".\reports\DomainInformation.csv" `
-NoTypeInformation `
-Encoding UTF8

Write-Host ""
Write-Host "Domain information exported successfully." -ForegroundColor Green
