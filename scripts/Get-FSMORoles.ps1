<#
.SYNOPSIS
    Retrieves all FSMO role holders in the Active Directory Forest.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.2.0
#>

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Collecting FSMO role holders..."

if (!(Test-RequiredModule -ModuleName ActiveDirectory)) { return }

try {

    $Forest = Get-ADForest
    $Domain = Get-ADDomain

    $FSMO = [PSCustomObject]@{

        SchemaMaster          = $Forest.SchemaMaster
        DomainNamingMaster    = $Forest.DomainNamingMaster
        PDCEmulator           = $Domain.PDCEmulator
        RIDMaster             = $Domain.RIDMaster
        InfrastructureMaster  = $Domain.InfrastructureMaster

    }

    $FSMO | Format-List

    Export-AssessmentCsv -Data $FSMO -Name "FSMORoles"

}
catch {
    Write-ErrorMessage "Failed to collect FSMO roles: $($_.Exception.Message)"
}
