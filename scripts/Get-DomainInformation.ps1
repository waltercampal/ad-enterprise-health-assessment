<#
.SYNOPSIS
    Retrieves Active Directory Domain information for all domains in the forest.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.3.0
#>

param(
    [PSCredential]$Credential
)

Import-Module ActiveDirectory

if ($Credential) {
    $Forest = Get-ADForest -Credential $Credential
}
else {
    $Forest = Get-ADForest
}

$DomainInfo = foreach ($DomainName in $Forest.Domains)
{
    if ($Credential) {
        $Domain = Get-ADDomain `
            -Identity $DomainName `
            -Server $DomainName `
            -Credential $Credential
    }
    else {
        $Domain = Get-ADDomain `
            -Identity $DomainName `
            -Server $DomainName
    }

    $DCCount = if ($Credential) {
        (Get-ADDomainController `
            -Server $DomainName `
            -Filter * `
            -Credential $Credential).Count
    }
    else {
        (Get-ADDomainController `
            -Server $DomainName `
            -Filter *).Count
    }

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