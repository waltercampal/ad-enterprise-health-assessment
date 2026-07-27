param(
    [Parameter(Mandatory)]
    $Forest,

    [Parameter(Mandatory)]
    $Domains,

    [Parameter(Mandatory)]
    $FSMO,

    [Parameter(Mandatory)]
    $DCs,

    [Parameter(Mandatory)]
    $Replication
)

$Errors = ($Replication | Where-Object {
    $_.LastReplicationResult -ne 0
}).Count

$ForestFSMO = $FSMO | Where-Object Scope -eq "Forest"
$DomainFSMO = $FSMO | Where-Object Scope -eq "Domain"

$Summary = @"
==========================================
Enterprise Active Directory Assessment
==========================================

Assessment Date
---------------
$(Get-Date)

Forest
------
Forest Name............. $($Forest.ForestName)
Forest Functional Level. $($Forest.ForestMode)

Domains
-------
$($Forest.DomainCount)

Domain Controllers
------------------
$($DCs.Count)

Global Catalogs
---------------
$($Forest.GlobalCatalogCount)

FSMO Roles
----------
"@

foreach($Role in $ForestFSMO)
{
    $Summary += "{0,-24} {1}`r`n" -f ($Role.Role + "..."), $Role.Server
}

$Summary += "`r`n"

foreach($Domain in ($DomainFSMO | Group-Object Domain))
{
    $Summary += "$($Domain.Name)`r`n"

    foreach($Role in $Domain.Group)
    {
        $Summary += "   {0,-20} {1}`r`n" -f ($Role.Role + "..."), $Role.Server
    }

    $Summary += "`r`n"
}

$Summary += @"

Replication
-----------
Partners................ $($Replication.Count)
Errors.................. $Errors

==========================================
Assessment completed successfully.
==========================================

"@

$Summary | Out-File ".\reports\ExecutiveSummary.txt" -Encoding UTF8

Write-Host ""
Write-Host "Executive summary exported successfully." -ForegroundColor Green

return $Summary