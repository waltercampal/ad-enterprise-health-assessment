<#
.SYNOPSIS
    Retrieves all FSMO role holders in the Active Directory Forest.

.DESCRIPTION
    Reports the 2 forest-wide roles (Schema Master, Domain Naming Master)
    once, and the 3 domain-wide roles (PDC Emulator, RID Master,
    Infrastructure Master) for every domain in the forest — not just the
    domain the machine running this happens to be joined to.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.3.0
#>

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Collecting FSMO role holders (all domains in the forest)..."

if (!(Test-RequiredModule -ModuleName ActiveDirectory)) { return }

try {

    $Forest = Get-ADForest

    $FSMO = foreach ($DomainName in (Get-ForestDomains)) {

        try {

            $Domain = Get-ADDomain -Server $DomainName -ErrorAction Stop

            [PSCustomObject]@{

                Domain                = $Domain.DNSRoot
                SchemaMaster          = $Forest.SchemaMaster
                DomainNamingMaster    = $Forest.DomainNamingMaster
                PDCEmulator           = $Domain.PDCEmulator
                RIDMaster             = $Domain.RIDMaster
                InfrastructureMaster  = $Domain.InfrastructureMaster

            }

        }
        catch {
            Write-WarningMessage "Could not query domain '$DomainName': $($_.Exception.Message)"
        }

    }

    $FSMO | Format-Table -AutoSize

    Export-AssessmentCsv -Data $FSMO -Name "FSMORoles"

}
catch {
    Write-ErrorMessage "Failed to collect FSMO roles: $($_.Exception.Message)"
}
