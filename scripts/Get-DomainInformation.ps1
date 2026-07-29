<#
.SYNOPSIS
    Retrieves Active Directory Domain information for all domains in the forest.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.3.1
#>

param(
    [System.Management.Automation.PSCredential]$Credential
)

Import-Module ActiveDirectory

$CredSplat = if ($Credential) { @{ Credential = $Credential } } else { @{} }

$Forest = Get-ADForest @CredSplat

$DomainInfo = foreach ($DomainName in $Forest.Domains)
{
    $Domain = Get-ADDomain `
        -Identity $DomainName `
        -Server $DomainName `
        @CredSplat

    $DCCount = (Get-ADDomainController `
        -Server $DomainName `
        -Filter * `
        @CredSplat).Count

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