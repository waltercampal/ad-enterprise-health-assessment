<#
.SYNOPSIS
    Renders the discovery, health and migration-readiness results into a
    single self-contained HTML report.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    1.0.0
#>

param(
    [Parameter(Mandatory)]
    $Forest,

    [Parameter(Mandatory)]
    [array]$DCs,

    [Parameter(Mandatory)]
    [array]$HealthResults,

    [Parameter(Mandatory)]
    $Score,

    [string]$OutputPath = ".\reports\AssessmentReport.html"
)

function Get-StatusBadge {
    param([string]$Status)

    $Class = switch ($Status) {
        'Healthy'  { 'badge-healthy' }
        'Warning'  { 'badge-warning' }
        'Critical' { 'badge-critical' }
        default    { 'badge-skipped' }
    }

    "<span class=`"badge $Class`">$Status</span>"
}

$Categories = $HealthResults | Group-Object -Property Category | Sort-Object Name

$CategorySections = foreach ($Category in $Categories) {

    $Rows = foreach ($Result in ($Category.Group | Sort-Object Status, Target)) {
        @"
        <tr>
            <td>$($Result.Check)</td>
            <td>$($Result.Target)</td>
            <td>$(Get-StatusBadge $Result.Status)</td>
            <td>$($Result.Severity)</td>
            <td>$($Result.Message)</td>
            <td>$($Result.Recommendation)</td>
        </tr>
"@
    }

    $Healthy  = @($Category.Group | Where-Object Status -eq 'Healthy').Count
    $Warning  = @($Category.Group | Where-Object Status -eq 'Warning').Count
    $Critical = @($Category.Group | Where-Object Status -eq 'Critical').Count
    $Skipped  = @($Category.Group | Where-Object Status -eq 'Skipped').Count

    @"
    <section class="category">
        <h2>$($Category.Name)
            <span class="counts">
                $Healthy healthy &middot; $Warning warning &middot; $Critical critical &middot; $Skipped skipped
            </span>
        </h2>
        <table>
            <thead>
                <tr><th>Check</th><th>Target</th><th>Status</th><th>Severity</th><th>Message</th><th>Recommendation</th></tr>
            </thead>
            <tbody>
                $($Rows -join "`n")
            </tbody>
        </table>
    </section>
"@
}

$DCsByOS = $DCs | Group-Object -Property OperatingSystem | Sort-Object Count -Descending
$DCOSRows = foreach ($Group in $DCsByOS) {
    "<tr><td>$($Group.Name)</td><td>$($Group.Count)</td></tr>"
}

$ScoreClass = if ($Score.Score -ge 90) { 'score-good' } elseif ($Score.Score -ge 70) { 'score-warning' } else { 'score-critical' }

$Html = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Enterprise AD Health Assessment - $($Forest.ForestName)</title>
<style>
    :root { color-scheme: light dark; }
    body {
        font-family: -apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif;
        margin: 0;
        padding: 2rem;
        background: #f5f6f8;
        color: #1c1e21;
    }
    @media (prefers-color-scheme: dark) {
        body { background: #14161a; color: #e6e8eb; }
        table, section.category { background: #1d2025 !important; }
        th { background: #262a31 !important; }
        td, th { border-color: #2e333b !important; }
        .card { background: #1d2025 !important; }
    }
    header { margin-bottom: 2rem; }
    h1 { margin: 0 0 0.25rem 0; font-size: 1.6rem; }
    .subtitle { opacity: 0.7; margin-bottom: 1.5rem; }
    .cards { display: flex; gap: 1rem; flex-wrap: wrap; margin-bottom: 2rem; }
    .card {
        background: #fff;
        border-radius: 10px;
        padding: 1rem 1.5rem;
        min-width: 160px;
        box-shadow: 0 1px 3px rgba(0,0,0,0.08);
    }
    .card .label { font-size: 0.8rem; opacity: 0.65; text-transform: uppercase; letter-spacing: 0.04em; }
    .card .value { font-size: 1.6rem; font-weight: 600; }
    .score-good .value { color: #1a7f37; }
    .score-warning .value { color: #b98900; }
    .score-critical .value { color: #cf222e; }
    section.category {
        background: #fff;
        border-radius: 10px;
        padding: 1rem 1.5rem;
        margin-bottom: 1.5rem;
        box-shadow: 0 1px 3px rgba(0,0,0,0.08);
        overflow-x: auto;
    }
    h2 { font-size: 1.1rem; display: flex; justify-content: space-between; align-items: baseline; flex-wrap: wrap; gap: 0.5rem; }
    .counts { font-size: 0.8rem; font-weight: normal; opacity: 0.7; }
    table { border-collapse: collapse; width: 100%; font-size: 0.85rem; }
    th, td { text-align: left; padding: 0.5rem 0.6rem; border-bottom: 1px solid #e5e7eb; vertical-align: top; }
    th { background: #f0f1f3; }
    .badge { display: inline-block; padding: 0.15rem 0.55rem; border-radius: 999px; font-size: 0.75rem; font-weight: 600; color: #fff; }
    .badge-healthy { background: #1a7f37; }
    .badge-warning { background: #b98900; }
    .badge-critical { background: #cf222e; }
    .badge-skipped { background: #6e7781; }
    footer { margin-top: 2rem; font-size: 0.8rem; opacity: 0.6; }
</style>
</head>
<body>
<header>
    <h1>Enterprise Active Directory Health Assessment</h1>
    <div class="subtitle">$($Forest.ForestName) &middot; generated $(Get-Date)</div>
</header>

<div class="cards">
    <div class="card $ScoreClass">
        <div class="label">Infrastructure Score</div>
        <div class="value">$($Score.Score) / 100</div>
    </div>
    <div class="card">
        <div class="label">Domain Controllers</div>
        <div class="value">$($DCs.Count)</div>
    </div>
    <div class="card">
        <div class="label">Domains</div>
        <div class="value">$($Forest.DomainCount)</div>
    </div>
    <div class="card">
        <div class="label">Healthy Checks</div>
        <div class="value">$($Score.HealthyCount)</div>
    </div>
    <div class="card">
        <div class="label">Warnings</div>
        <div class="value">$($Score.WarningCount)</div>
    </div>
    <div class="card">
        <div class="label">Critical Findings</div>
        <div class="value">$($Score.CriticalCount)</div>
    </div>
</div>

<section class="category">
    <h2>Domain Controllers by Operating System</h2>
    <table>
        <thead><tr><th>Operating System</th><th>Count</th></tr></thead>
        <tbody>
            $($DCOSRows -join "`n")
        </tbody>
    </table>
</section>

$($CategorySections -join "`n")

<footer>
    Enterprise Active Directory Health Assessment Toolkit &middot; Walter Campal
</footer>
</body>
</html>
"@

$Html | Out-File -FilePath $OutputPath -Encoding UTF8

Write-Host ""
Write-Host "HTML report exported: $OutputPath" -ForegroundColor Green

return $OutputPath
