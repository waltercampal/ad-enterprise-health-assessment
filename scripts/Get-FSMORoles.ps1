<#
.SYNOPSIS
    Retrieves all FSMO role holders.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.2.0
#>

param(
    [PSCredential]$Credential
)

Import-Module ActiveDirectory

if ($Credential) {
    $Forest = Get-ADForest -Credential $Credential
    $Domain = Get-ADDomain -Credential $Credential
}
else {
    $Forest = Get-ADForest
    $Domain = Get-ADDomain
}

$FSMOInfo = [PSCustomObject]@{

    SchemaMaster       = $Forest.SchemaMaster
    DomainNamingMaster = $Forest.DomainNamingMaster
    PDCEmulator        = $Domain.PDCEmulator
    RIDMaster          = $Domain.RIDMaster
    InfrastructureMaster = $Domain.InfrastructureMaster

}

return $FSMOInfo