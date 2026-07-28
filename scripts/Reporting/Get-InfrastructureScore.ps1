<#
.SYNOPSIS
    Computes a single Infrastructure Score (0-100) from a collection of
    ADEHAT.HealthResult objects, weighted by severity.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    1.0.0
#>

param(
    [Parameter(Mandatory)]
    [array]$HealthResults
)

$SeverityWeight = @{
    Info   = 1
    Low    = 1
    Medium = 2
    High   = 3
}

$Scored = $HealthResults | Where-Object { $_.Status -ne 'Skipped' }

$PossiblePoints = 0
$EarnedPoints = 0

foreach ($Result in $Scored) {

    $Weight = $SeverityWeight[$Result.Severity]
    if (-not $Weight) { $Weight = 1 }

    $PossiblePoints += $Weight

    switch ($Result.Status) {
        'Healthy'  { $EarnedPoints += $Weight }
        'Warning'  { $EarnedPoints += ($Weight * 0.5) }
        'Critical' { $EarnedPoints += 0 }
    }
}

$Score = if ($PossiblePoints -eq 0) { 100 } else { [math]::Round(($EarnedPoints / $PossiblePoints) * 100) }

return [PSCustomObject]@{
    Score          = $Score
    PossiblePoints = $PossiblePoints
    EarnedPoints   = [math]::Round($EarnedPoints, 1)
    HealthyCount   = @($Scored | Where-Object Status -eq 'Healthy').Count
    WarningCount   = @($Scored | Where-Object Status -eq 'Warning').Count
    CriticalCount  = @($Scored | Where-Object Status -eq 'Critical').Count
    SkippedCount   = @($HealthResults | Where-Object Status -eq 'Skipped').Count
}
