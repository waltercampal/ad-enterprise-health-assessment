<#
.SYNOPSIS
    Retrieves Active Directory Domain information for all domains in the forest.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.3.1
#>

Import-Module ActiveDirectory

$Forest = Get-ADForest

$DomainInfo = foreach ($DomainName in $Forest.Domains)
{
    $Domain = Get-ADDomain `
        -Identity $DomainName `
        -Server $DomainName

    $DCCount = (Get-ADDomainController `
        -Server $DomainName `
        -Filter *).Count

    [PSCustomObject]@{

        DomainName            = $Domain.DNSRoot
        NetBIOSName           = $Domain.NetBIOSName
        DomainMode            = $Domain.DomainMode
        DomainControllers     = $DCCount
        ChildDomains          = $Domain.ChildDomains.Count

        PDCEmulator           = $Domain.PDCEmulator
        RIDMaster             = $Domain.RIDMaster
        InfrastructureMaster  = $Domain.InfrastructureMaster

    }
}

return $DomainInfo