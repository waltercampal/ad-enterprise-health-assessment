<#
.SYNOPSIS
    Builds a single-file HTML executive dashboard from the assessment CSV reports.

.DESCRIPTION
    Reads every CSV report produced by the assessment modules in reports/,
    computes a health status (OK / Warning / Failure) per area using
    known indicator columns, rolls those up into an overall Infrastructure
    Health Score, and renders a self-contained HTML report
    (reports/AssessmentDashboard.html) with a scorecard, traffic-light area
    cards, and collapsible detail tables per module.

    Works on real assessment output or on fictitious data produced by
    New-DemoData.ps1 — the CSV schema is identical either way.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.1.0
#>

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Building Infrastructure Health Dashboard..."

Initialize-ReportsFolder

function Get-ReportRows {
    param([Parameter(Mandatory)][string]$Name)

    $Path = Join-Path $ReportsPath "$Name.csv"
    if (Test-Path $Path) {
        return @(Import-Csv -Path $Path)
    }
    return @()
}

function New-AreaResult {
    param(
        [Parameter(Mandatory)][string]$AreaName,
        [Parameter(Mandatory)][int]$Total,
        [Parameter(Mandatory)][int]$OK,
        [string]$Note = ""
    )

    $Status = if ($Total -eq 0) { "info" }
              elseif ($OK -eq $Total) { "ok" }
              elseif ($OK -ge [math]::Ceiling($Total * 0.6)) { "warn" }
              else { "fail" }

    [PSCustomObject]@{
        AreaName = $AreaName
        Total    = $Total
        OK       = $OK
        Status   = $Status
        Note     = $Note
    }
}

function ConvertTo-HtmlTable {
    param($Rows)

    if (-not $Rows -or $Rows.Count -eq 0) {
        return "<p class='empty'>No data collected for this module.</p>"
    }

    $Columns = $Rows[0].PSObject.Properties.Name

    $Sb = New-Object System.Text.StringBuilder
    [void]$Sb.Append("<table><thead><tr>")
    foreach ($Col in $Columns) { [void]$Sb.Append("<th>$([System.Net.WebUtility]::HtmlEncode($Col))</th>") }
    [void]$Sb.Append("</tr></thead><tbody>")

    foreach ($Row in $Rows) {
        [void]$Sb.Append("<tr>")
        foreach ($Col in $Columns) {
            $Value = [string]$Row.$Col
            [void]$Sb.Append("<td>$([System.Net.WebUtility]::HtmlEncode($Value))</td>")
        }
        [void]$Sb.Append("</tr>")
    }

    [void]$Sb.Append("</tbody></table>")
    return $Sb.ToString()
}

# ---------------------------------------------------------------------------
# Load data
# ---------------------------------------------------------------------------

$ForestInfo = Get-ReportRows "ForestInformation"
$DomainInfo = Get-ReportRows "DomainInformation"
$FsmoInfo   = Get-ReportRows "FSMORoles"
$DcInventory = Get-ReportRows "DomainControllerInventory"
$SiteTopology = Get-ReportRows "SiteTopology"
$SiteLinks = Get-ReportRows "SiteLinks"
$Replication = Get-ReportRows "ReplicationStatus"
$Sysvol = Get-ReportRows "SysvolHealth"
$DnsZones = Get-ReportRows "DnsZones"
$DnsServers = Get-ReportRows "DnsServers"
$GpoInventory = Get-ReportRows "GPOInventory"
$SecurityBaseline = Get-ReportRows "SecurityBaseline"
$DhcpScopes = Get-ReportRows "DhcpScopes"
$CertServices = Get-ReportRows "CertificateServices"
$FileShares = Get-ReportRows "FileShares"
$DiskCapacity = Get-ReportRows "DiskCapacity"
$DfsHealth = Get-ReportRows "DfsNamespaceHealth"
$EventLogs = Get-ReportRows "EventLogAnalysis"
$WindowsServices = Get-ReportRows "WindowsServices"
$EntraScheduler = Get-ReportRows "EntraConnectScheduler"
$EntraConnectorRuns = Get-ReportRows "EntraConnectConnectorRuns"
$PtaAgents = Get-ReportRows "PtaAgentStatus"
$CloudSync = Get-ReportRows "CloudSyncStatus"
$EntraId = Get-ReportRows "EntraIdAssessment"
$ConditionalAccess = Get-ReportRows "ConditionalAccessPolicies"

# ---------------------------------------------------------------------------
# Score each area
# ---------------------------------------------------------------------------

$Areas = @()

$Areas += New-AreaResult -AreaName "Domain Controllers" -Total $DcInventory.Count `
    -OK (@($DcInventory | Where-Object { $_.Online -eq "Yes" })).Count

$Areas += New-AreaResult -AreaName "Replication" -Total $Replication.Count `
    -OK (@($Replication | Where-Object { $_.Status -eq "OK" })).Count

$Areas += New-AreaResult -AreaName "SYSVOL / DFSR" -Total $Sysvol.Count `
    -OK (@($Sysvol | Where-Object { $_.State -eq "Normal" })).Count

$UnlinkedActiveGpos = @($GpoInventory | Where-Object { $_.LinkCount -eq "0" -and $_.GpoStatus -ne "AllSettingsDisabled" })
$Areas += New-AreaResult -AreaName "Group Policy" -Total $GpoInventory.Count `
    -OK ($GpoInventory.Count - $UnlinkedActiveGpos.Count)

$Areas += New-AreaResult -AreaName "Security Baseline" -Total $SecurityBaseline.Count `
    -OK (@($SecurityBaseline | Where-Object { $_.Severity -eq "OK" })).Count

$DhcpOk = @($DhcpScopes | Where-Object {
    $Pct = $_.PercentageInUse -as [double]
    $null -ne $Pct -and $Pct -lt 85
})
$Areas += New-AreaResult -AreaName "DHCP" -Total $DhcpScopes.Count -OK $DhcpOk.Count

$Areas += New-AreaResult -AreaName "Certificate Services" -Total $CertServices.Count `
    -OK (@($CertServices | Where-Object { $_.Reachable -eq "Yes" })).Count

$DiskOk = @($DiskCapacity | Where-Object {
    $Pct = $_.FreePercent -as [double]
    $null -ne $Pct -and $Pct -ge 15
})
$Areas += New-AreaResult -AreaName "File Services / Disk Capacity" -Total $DiskCapacity.Count -OK $DiskOk.Count

$DfsOk = @($DfsHealth | Where-Object { $_.State -eq "Online" })
$Areas += New-AreaResult -AreaName "DFS Namespaces" -Total $DfsHealth.Count -OK $DfsOk.Count

$EventOk = @($EventLogs | Where-Object {
    $Count = $_.ErrorCount -as [int]
    $null -ne $Count -and $Count -le 20
})
$Areas += New-AreaResult -AreaName "Event Logs (24h)" -Total $EventLogs.Count -OK $EventOk.Count

$SvcOk = @($WindowsServices | Where-Object { $_.Healthy -eq "True" })
$Areas += New-AreaResult -AreaName "Windows Services" -Total $WindowsServices.Count -OK $SvcOk.Count

$HybridTotal = 0
$HybridOk = 0
if ($EntraConnectorRuns.Count -gt 0) {
    $HybridTotal += $EntraConnectorRuns.Count
    $HybridOk += (@($EntraConnectorRuns | Where-Object { $_.LastRunResult -eq "success" })).Count
}
if ($PtaAgents.Count -gt 0) {
    $HybridTotal += $PtaAgents.Count
    $HybridOk += (@($PtaAgents | Where-Object { $_.Healthy -eq "True" })).Count
}
if ($CloudSync.Count -gt 0) {
    $HybridTotal += $CloudSync.Count
    $HybridOk += (@($CloudSync | Where-Object { $_.Healthy -eq "True" })).Count
}
if ($ConditionalAccess.Count -gt 0) {
    $HybridTotal += $ConditionalAccess.Count
    $HybridOk += (@($ConditionalAccess | Where-Object { $_.State -eq "enabled" })).Count
}
$Areas += New-AreaResult -AreaName "Hybrid Identity" -Total $HybridTotal -OK $HybridOk

# ---------------------------------------------------------------------------
# Overall score
# ---------------------------------------------------------------------------

$ScoredAreas = @($Areas | Where-Object { $_.Total -gt 0 })
$TotalChecks = ($ScoredAreas | Measure-Object -Property Total -Sum).Sum
$TotalOK = ($ScoredAreas | Measure-Object -Property OK -Sum).Sum

$OverallScore = if ($TotalChecks -gt 0) { [math]::Round(($TotalOK / $TotalChecks) * 100) } else { 0 }

$Grade = switch ($OverallScore) {
    { $_ -ge 90 } { "Excellent"; break }
    { $_ -ge 75 } { "Good"; break }
    { $_ -ge 60 } { "Needs Attention"; break }
    default { "Critical" }
}

$ScoreColor = switch ($OverallScore) {
    { $_ -ge 90 } { "#2e7d4f"; break }
    { $_ -ge 75 } { "#3f7d3f"; break }
    { $_ -ge 60 } { "#b8860b"; break }
    default { "#b03030" }
}

$DomainName = if ($DomainInfo.Count -gt 0) { $DomainInfo[0].DomainName } else { "Unknown Domain" }
$GeneratedOn = Get-Date -Format "yyyy-MM-dd HH:mm"

# ---------------------------------------------------------------------------
# Render HTML
# ---------------------------------------------------------------------------

$StatusLabel = @{ ok = "Healthy"; warn = "Needs Review"; fail = "Critical"; info = "Informational" }

$AreaCardsHtml = ($Areas | ForEach-Object {
    $Pct = if ($_.Total -gt 0) { [math]::Round(($_.OK / $_.Total) * 100) } else { $null }
    $PctText = if ($null -ne $Pct) { "$Pct% ($($_.OK)/$($_.Total))" } else { "No data" }
    "<div class='card status-$($_.Status)'><div class='card-title'>$($_.AreaName)</div><div class='card-badge'>$($StatusLabel[$_.Status])</div><div class='card-pct'>$PctText</div></div>"
}) -join "`n"

$Sections = [ordered]@{
    "Forest Information"          = $ForestInfo
    "Domain Information"          = $DomainInfo
    "FSMO Roles"                  = $FsmoInfo
    "Domain Controller Inventory" = $DcInventory
    "Site Topology"                = $SiteTopology
    "Site Links"                   = $SiteLinks
    "Replication Status"          = $Replication
    "SYSVOL / DFSR Health"        = $Sysvol
    "DNS Zones"                    = $DnsZones
    "DNS Servers"                  = $DnsServers
    "Group Policy Inventory"      = $GpoInventory
    "Security Baseline"           = $SecurityBaseline
    "DHCP Scopes"                  = $DhcpScopes
    "Certificate Services"        = $CertServices
    "File Shares"                  = $FileShares
    "Disk Capacity"                = $DiskCapacity
    "DFS Namespace Health"        = $DfsHealth
    "Event Log Analysis (24h)"    = $EventLogs
    "Windows Services"             = $WindowsServices
    "Entra Connect Scheduler"     = $EntraScheduler
    "Entra Connect Connector Runs" = $EntraConnectorRuns
    "PTA Agent Status"             = $PtaAgents
    "Cloud Sync Status"            = $CloudSync
    "Entra ID Assessment"          = $EntraId
    "Conditional Access Policies" = $ConditionalAccess
}

$SectionsHtml = ($Sections.GetEnumerator() | ForEach-Object {
    "<details><summary>$($_.Key) <span class='count'>($($_.Value.Count))</span></summary><div class='table-wrap'>$(ConvertTo-HtmlTable -Rows $_.Value)</div></details>"
}) -join "`n"

$Html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>AD Infrastructure Health Dashboard</title>
<style>
    :root { color-scheme: light; }
    * { box-sizing: border-box; }
    body {
        margin: 0;
        background: #f4f6f8;
        color: #1c2530;
        font-family: 'Segoe UI', Tahoma, Arial, sans-serif;
    }
    header {
        background: #12233f;
        color: #fff;
        padding: 28px 40px;
    }
    header h1 { margin: 0 0 4px 0; font-size: 22px; }
    header .meta { color: #b7c4d9; font-size: 13px; }
    .container { max-width: 1100px; margin: 0 auto; padding: 32px 24px 60px; }
    .scorecard {
        display: flex;
        align-items: center;
        gap: 28px;
        background: #fff;
        border-radius: 10px;
        padding: 24px 28px;
        box-shadow: 0 1px 3px rgba(0,0,0,0.08);
        margin-bottom: 28px;
    }
    .score-circle {
        width: 110px; height: 110px; border-radius: 50%;
        display: flex; align-items: center; justify-content: center;
        flex-direction: column;
        border: 8px solid $ScoreColor;
        color: $ScoreColor;
        font-weight: 700;
    }
    .score-circle .num { font-size: 30px; line-height: 1; }
    .score-circle .pct { font-size: 11px; }
    .score-text h2 { margin: 0 0 6px 0; font-size: 18px; color: $ScoreColor; }
    .score-text p { margin: 0; color: #4a5568; font-size: 13px; }
    .cards {
        display: grid;
        grid-template-columns: repeat(auto-fill, minmax(210px, 1fr));
        gap: 14px;
        margin-bottom: 36px;
    }
    .card {
        background: #fff;
        border-radius: 8px;
        padding: 14px 16px;
        border-left: 5px solid #ccc;
        box-shadow: 0 1px 2px rgba(0,0,0,0.06);
    }
    .card-title { font-size: 13px; font-weight: 600; color: #1c2530; margin-bottom: 6px; }
    .card-badge { font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: .03em; margin-bottom: 4px; }
    .card-pct { font-size: 12px; color: #667085; }
    .card.status-ok { border-left-color: #2e7d4f; }
    .card.status-ok .card-badge { color: #2e7d4f; }
    .card.status-warn { border-left-color: #b8860b; }
    .card.status-warn .card-badge { color: #b8860b; }
    .card.status-fail { border-left-color: #b03030; }
    .card.status-fail .card-badge { color: #b03030; }
    .card.status-info { border-left-color: #8492a6; }
    .card.status-info .card-badge { color: #8492a6; }
    h2.section-title { font-size: 16px; margin: 28px 0 12px; color: #12233f; }
    details {
        background: #fff;
        border-radius: 8px;
        margin-bottom: 10px;
        box-shadow: 0 1px 2px rgba(0,0,0,0.06);
        overflow: hidden;
    }
    summary {
        cursor: pointer;
        padding: 12px 16px;
        font-weight: 600;
        font-size: 13.5px;
        list-style: none;
    }
    summary::-webkit-details-marker { display: none; }
    summary .count { font-weight: 400; color: #8492a6; margin-left: 6px; }
    .table-wrap { overflow-x: auto; padding: 0 16px 16px; }
    table { border-collapse: collapse; width: 100%; font-size: 12.5px; }
    th, td { text-align: left; padding: 6px 10px; border-bottom: 1px solid #eef0f3; white-space: nowrap; }
    th { color: #667085; font-weight: 600; background: #fafbfc; }
    p.empty { color: #8492a6; font-size: 13px; padding: 0 16px 16px; }
    footer { text-align: center; color: #8492a6; font-size: 12px; padding: 20px; }
</style>
</head>
<body>
<header>
    <h1>Active Directory Infrastructure Health Dashboard</h1>
    <div class="meta">Domain: $DomainName &nbsp;|&nbsp; Generated: $GeneratedOn &nbsp;|&nbsp; Horizon Labs Enterprise AD Health Assessment Toolkit</div>
</header>
<div class="container">
    <div class="scorecard">
        <div class="score-circle"><span class="num">$OverallScore</span><span class="pct">/ 100</span></div>
        <div class="score-text">
            <h2>Overall Infrastructure Health: $Grade</h2>
            <p>$TotalOK of $TotalChecks checks passed across $($ScoredAreas.Count) assessed areas.</p>
        </div>
    </div>

    <div class="cards">
$AreaCardsHtml
    </div>

    <h2 class="section-title">Detailed Findings</h2>
$SectionsHtml
</div>
<footer>Generated by the Enterprise Active Directory Health Assessment Toolkit &mdash; Horizon Labs</footer>
</body>
</html>
"@

$OutputPath = Join-Path $ReportsPath "AssessmentDashboard.html"
$Html | Out-File -FilePath $OutputPath -Encoding UTF8

Write-Success "Dashboard generated: $OutputPath"
