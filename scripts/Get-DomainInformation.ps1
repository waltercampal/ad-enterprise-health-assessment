<#
.SYNOPSIS
    Retrieves Active Directory Domain information for every domain in the forest.

.DESCRIPTION
    Enumerates every domain in the forest (root domain and every child/tree
    domain) and collects each one's domain mode, NetBIOS name, and FSMO
    role holders — not just the domain the machine running this happens to
    be joined to.

.AUTHOR
    Walter Campal
    Horizon Labs

.PARAMETER Credential
    Optional alternate credential to query every domain with.

.VERSION
    0.4.0
#>

param(
    [PSCredential]$Credential
)

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Collecting Domain information (all domains in the forest)..."

if (!(Test-RequiredModule -ModuleName ActiveDirectory)) { return }

try {

    $AdParams = @{ ErrorAction = "Stop" }
    if ($Credential) { $AdParams["Credential"] = $Credential }

    $Info = foreach ($DomainName in (Get-ForestDomains -Credential $Credential)) {

        try {

            $Domain = Get-ADDomain @AdParams -Server $DomainName

            [PSCustomObject]@{

                DomainName            = $Domain.DNSRoot
                NetBIOSName           = $Domain.NetBIOSName
                DomainMode            = $Domain.DomainMode
                DistinguishedName     = $Domain.DistinguishedName
                ParentDomain          = $Domain.ParentDomain
                PDCEmulator           = $Domain.PDCEmulator
                RIDMaster             = $Domain.RIDMaster
                InfrastructureMaster  = $Domain.InfrastructureMaster

            }

        }
        catch {
            Write-WarningMessage "Could not query domain '$DomainName': $($_.Exception.Message)"
        }

    }

    $Info | Format-Table -AutoSize

    Export-AssessmentCsv -Data $Info -Name "DomainInformation"

}
catch {
    Write-ErrorMessage "Failed to collect Domain information: $($_.Exception.Message)"
}
