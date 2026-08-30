<#
.SYNOPSIS
    Retrieves Active Directory Domain information.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.2.0
#>

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Collecting Domain information..."

if (!(Test-RequiredModule -ModuleName ActiveDirectory)) { return }

try {

    $Domain = Get-ADDomain

    $Info = [PSCustomObject]@{

        DomainName            = $Domain.DNSRoot
        NetBIOSName           = $Domain.NetBIOSName
        DomainMode            = $Domain.DomainMode
        DistinguishedName     = $Domain.DistinguishedName
        ParentDomain          = $Domain.ParentDomain
        PDCEmulator           = $Domain.PDCEmulator
        RIDMaster             = $Domain.RIDMaster
        InfrastructureMaster  = $Domain.InfrastructureMaster

    }

    $Info | Format-List

    Export-AssessmentCsv -Data $Info -Name "DomainInformation"

}
catch {
    Write-ErrorMessage "Failed to collect Domain information: $($_.Exception.Message)"
}
