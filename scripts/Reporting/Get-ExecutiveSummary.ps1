<#
.SYNOPSIS
    Generates a plain-text executive summary from the discovery and health
    assessment results.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    2.0.0
#>

param(
    [Parameter(Mandatory)]
    $Forest,

    [Parameter(Mandatory)]
    [array]$FSMO,

    [Parameter(Mandatory)]
    [array]$DCs,

    [Parameter(Mandatory)]
    [array]$HealthResults,

    [Parameter(Mandatory)]
    $Score
)

$ForestFSMO = $FSMO | Where-Object Scope -eq "Forest"
$DomainFSMO = $FSMO | Where-Object Scope -eq "Domain"

$OSCounts = $DCs | Group-Object -Property OperatingSystem

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
Total.................... $($DCs.Count)
"@

foreach ($OSGroup in ($OSCounts | Sort-Object Count -Descending)) {
    $Summary += "`r`n{0,-24} {1}" -f ($OSGroup.Name + "..."), $OSGroup.Count
}

$Summary += @"


Global Catalogs
---------------
$($Forest.GlobalCatalogCount)

FSMO Roles
----------
"@

foreach ($Role in $ForestFSMO) {
    $Summary += "`r`n{0,-24} {1}" -f ($Role.Role + "..."), $Role.Server
}

$Summary += "`r`n`r`n"

foreach ($Domain in ($DomainFSMO | Group-Object Domain)) {
    $Summary += "$($Domain.Name)`r`n"

    foreach ($Role in $Domain.Group) {
        $Summary += "   {0,-20} {1}`r`n" -f ($Role.Role + "..."), $Role.Server
    }

    $Summary += "`r`n"
}

$Summary += @"
Health Summary
--------------
{0,-28} {1,7} {2,8} {3,9} {4,8}
"@ -f "Category", "Healthy", "Warning", "Critical", "Skipped"

$ByCategory = $HealthResults | Group-Object -Property Category | Sort-Object Name

foreach ($Category in $ByCategory) {
    $Healthy  = @($Category.Group | Where-Object Status -eq 'Healthy').Count
    $Warning  = @($Category.Group | Where-Object Status -eq 'Warning').Count
    $Critical = @($Category.Group | Where-Object Status -eq 'Critical').Count
    $Skipped  = @($Category.Group | Where-Object Status -eq 'Skipped').Count

    $Summary += "`r`n" + ("{0,-28} {1,7} {2,8} {3,9} {4,8}" -f $Category.Name, $Healthy, $Warning, $Critical, $Skipped)
}

$MigrationFindings = $HealthResults | Where-Object Category -eq 'MigrationReadiness'

$Summary += @"


Migration Readiness (Windows Server 2016 -> 2022)
--------------------------------------------------
"@

foreach ($Finding in $MigrationFindings) {
    $Summary += "`r`n{0,-14} {1}: {2}" -f $Finding.Status, $Finding.Check, $Finding.Message
}

$Summary += @"


Infrastructure Score
---------------------
$($Score.Score) / 100  ($($Score.HealthyCount) healthy, $($Score.WarningCount) warning, $($Score.CriticalCount) critical, $($Score.SkippedCount) skipped)

==========================================
Assessment completed successfully.
==========================================

"@

$Summary | Out-File ".\reports\ExecutiveSummary.txt" -Encoding UTF8

Write-Host ""
Write-Host "Executive summary exported successfully." -ForegroundColor Green

return $Summary
