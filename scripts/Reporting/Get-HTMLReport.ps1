<#
.SYNOPSIS
    Renders the discovery, health and migration-readiness results into a
    single self-contained HTML report.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    2.1.0
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

function HtmlEncode {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return "" }
    [System.Net.WebUtility]::HtmlEncode($Text)
}

function Get-StatusChip {
    param([string]$Status)

    $Class = switch ($Status) {
        'Healthy'  { 'st-healthy' }
        'Warning'  { 'st-warning' }
        'Critical' { 'st-critical' }
        default    { 'st-skipped' }
    }

    "<span class=`"chip $Class`"><i class=`"dot`"></i>$Status</span>"
}

function Get-DonutSvg {
    <#
    .SYNOPSIS
        Renders a two-tone ring: the Healthy share in green, the remaining
        (Warning/Critical/Skipped) share in whatever severity color applies.
    #>
    param(
        [double]$HealthyPercent,
        [string]$ReviewClass = 'rev-good',
        [int]$Size = 92,
        [int]$Stroke = 10
    )

    $R = [math]::Round(($Size / 2) - ($Stroke * 1.3), 2)
    $C = [math]::Round(2 * [math]::PI * $R, 2)
    $HealthyLen = [math]::Round($C * ($HealthyPercent / 100), 2)
    $ReviewLen  = [math]::Round($C - $HealthyLen, 2)
    $Half = $Size / 2

    @"
<svg width="$Size" height="$Size" viewBox="0 0 $Size $Size" class="donut-svg">
  <circle class="donut-track" cx="$Half" cy="$Half" r="$R" stroke-width="$Stroke"></circle>
  <circle class="donut-arc rev-good" cx="$Half" cy="$Half" r="$R" stroke-width="$Stroke"
    stroke-dasharray="$HealthyLen $C" stroke-dashoffset="0"></circle>
  <circle class="donut-arc $ReviewClass" cx="$Half" cy="$Half" r="$R" stroke-width="$Stroke"
    stroke-dasharray="$ReviewLen $C" stroke-dashoffset="-$HealthyLen"></circle>
</svg>
"@
}

# ---------------------------------------------------------------
# Static CSS / JS (no PowerShell interpolation inside these blocks)
# ---------------------------------------------------------------

$Css = @'
:root{
  color-scheme: light;
  --bg:#f9f9f7; --surface:#fcfcfb; --surface-2:#f2f2ef;
  --ink:#0b0b0b; --ink-2:#52514e; --ink-muted:#898781;
  --border:rgba(11,11,11,.10); --grid:#e1e0d9;
  --accent:#2a78d6; --accent-ink:#ffffff;
  --good:#0ca30c; --warning:#fab219; --critical:#d03b3b; --skipped:#898781;
  --font-display:"Iowan Old Style","Palatino Linotype",Palatino,Georgia,serif;
  --font-body:-apple-system,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;
  --font-mono:"SF Mono","Cascadia Code",Consolas,"Liberation Mono",monospace;
}
@media (prefers-color-scheme: dark){
  :root:where(:not([data-theme="light"])){
    color-scheme: dark;
    --bg:#0d0d0d; --surface:#1a1a19; --surface-2:#20201e;
    --ink:#ffffff; --ink-2:#c3c2b7; --ink-muted:#898781;
    --border:rgba(255,255,255,.10); --grid:#2c2c2a;
    --accent:#3987e5; --accent-ink:#0b0b0b;
  }
}
:root[data-theme="dark"]{
  color-scheme: dark;
  --bg:#0d0d0d; --surface:#1a1a19; --surface-2:#20201e;
  --ink:#ffffff; --ink-2:#c3c2b7; --ink-muted:#898781;
  --border:rgba(255,255,255,.10); --grid:#2c2c2a;
  --accent:#3987e5; --accent-ink:#0b0b0b;
}
*{box-sizing:border-box}
body{
  margin:0; background:var(--bg); color:var(--ink); font-family:var(--font-body);
  -webkit-font-smoothing:antialiased;
}
a{color:var(--accent)}
.wrap{max-width:1180px;margin:0 auto;padding:0 1.5rem 4rem}
button{font:inherit}
button:focus-visible, a:focus-visible{outline:2px solid var(--accent); outline-offset:2px}

header.top{
  position:sticky; top:0; z-index:20; background:var(--bg);
  border-bottom:1px solid var(--border); padding:1.25rem 1.5rem 1rem;
  backdrop-filter:saturate(180%) blur(8px);
}
header.top .row{max-width:1180px;margin:0 auto;display:flex;align-items:center;gap:1.5rem;flex-wrap:wrap}
.masthead h1{
  font-family:var(--font-display); font-size:1.5rem; font-weight:600; margin:0;
  text-wrap:balance; letter-spacing:.01em;
}
.masthead .meta{color:var(--ink-muted); font-size:.85rem; margin-top:.15rem}
.masthead .meta b{color:var(--ink-2); font-weight:600}
.theme-toggle{
  margin-left:auto; border:1px solid var(--border); background:var(--surface);
  color:var(--ink-2); border-radius:999px; padding:.4rem .8rem; cursor:pointer;
  font-size:.8rem;
}

.hero{display:flex; gap:2rem; align-items:center; padding:1.75rem 0; flex-wrap:wrap}
.gauge{position:relative; width:132px; height:132px; flex:none}
.gauge svg{transform:rotate(-90deg)}
.gauge .track{fill:none; stroke:var(--grid); stroke-width:10}
.gauge .fill{fill:none; stroke:var(--accent); stroke-width:10; stroke-linecap:round; transition:stroke-dashoffset .6s ease}
.gauge .label{
  position:absolute; inset:0; display:flex; flex-direction:column; align-items:center; justify-content:center;
}
.gauge .num{font-family:var(--font-display); font-size:2.1rem; font-weight:600; font-variant-numeric:tabular-nums; line-height:1}
.gauge .of{font-size:.7rem; color:var(--ink-muted); letter-spacing:.05em; text-transform:uppercase; margin-top:.2rem}

.stats{display:grid; grid-template-columns:repeat(auto-fit,minmax(120px,1fr)); gap:1px; background:var(--border); border:1px solid var(--border); border-radius:12px; overflow:hidden; flex:1; min-width:280px}
.stat{background:var(--surface); padding:.9rem 1rem}
.stat .n{font-family:var(--font-mono); font-variant-numeric:tabular-nums; font-size:1.5rem; font-weight:600}
.stat .l{font-size:.72rem; color:var(--ink-muted); text-transform:uppercase; letter-spacing:.06em; margin-top:.15rem}
.stat.good .n{color:var(--good)}
.stat.warning .n{color:var(--warning)}
.stat.critical .n{color:var(--critical)}

.section-title{
  font-family:var(--font-display); font-size:1.05rem; font-weight:600; margin:0 0 .9rem;
}

.dashboard{padding:.5rem 0 1.5rem}
.dash-grid{display:grid; grid-template-columns:repeat(auto-fill,minmax(148px,1fr)); gap:.85rem}
.dash-card{
  background:var(--surface); border:1px solid var(--border); border-radius:12px;
  padding:1rem .75rem; display:flex; flex-direction:column; align-items:center; gap:.5rem;
  text-decoration:none; color:inherit; text-align:center; transition:transform .15s ease, border-color .15s ease;
}
.dash-card:hover{transform:translateY(-2px); border-color:var(--accent)}
.dash-donut{position:relative; width:92px; height:92px; flex:none}
.donut-svg{transform:rotate(-90deg)}
.donut-track{fill:none; stroke:var(--grid)}
.donut-arc{fill:none; stroke-linecap:round; transition:stroke-dashoffset .6s ease}
.donut-arc.rev-good{stroke:var(--good)}
.donut-arc.rev-warning{stroke:var(--warning)}
.donut-arc.rev-critical{stroke:var(--critical)}
.donut-arc.rev-skipped{stroke:var(--skipped)}
.dash-label{position:absolute; inset:0; display:flex; flex-direction:column; align-items:center; justify-content:center}
.dash-pct{font-family:var(--font-mono); font-variant-numeric:tabular-nums; font-size:1.15rem; font-weight:600}
.dash-sub{font-size:.6rem; color:var(--ink-muted); text-transform:uppercase; letter-spacing:.05em}
.dash-name{font-weight:600; font-size:.88rem}
.dash-count{font-size:.72rem; color:var(--ink-muted)}
.dash-count b.crit{color:var(--critical)}
.dash-count b.warn{color:#9a6b00}
:root[data-theme="dark"] .dash-count b.warn, @media (prefers-color-scheme:dark){.dash-count b.warn{color:var(--warning)}}

.spotlight{padding:.5rem 0 2rem}
.spot-grid{display:grid; grid-template-columns:repeat(auto-fill,minmax(260px,1fr)); gap:.85rem}
.spot-card{
  background:var(--surface); border:1px solid var(--border); border-left:4px solid var(--ink-muted);
  border-radius:10px; padding:.85rem 1rem; display:flex; flex-direction:column; gap:.3rem;
}
.spot-card.spot-Critical{border-left-color:var(--critical)}
.spot-card.spot-Warning{border-left-color:var(--warning)}
.spot-top{display:flex; align-items:center; justify-content:space-between; gap:.5rem}
.spot-cat{font-size:.7rem; color:var(--ink-muted); text-transform:uppercase; letter-spacing:.06em; font-weight:600}
.spot-check{font-weight:600; font-size:.92rem}
.spot-msg{color:var(--ink-2); font-size:.85rem}
.spot-target{font-family:var(--font-mono); font-size:.75rem; color:var(--ink-muted)}
.spot-empty{color:var(--ink-muted); font-size:.9rem}

.filterbar{
  display:flex; gap:.5rem; align-items:center; flex-wrap:wrap; padding:.75rem 0 1.25rem;
  border-bottom:1px solid var(--border); margin-bottom:1.75rem; font-size:.85rem; color:var(--ink-muted);
}
.chipbtn{
  border:1px solid var(--border); background:var(--surface); color:var(--ink-2);
  border-radius:999px; padding:.3rem .75rem; cursor:pointer; display:inline-flex; align-items:center; gap:.4rem;
}
.chipbtn .dot{width:7px;height:7px;border-radius:50%;background:currentColor}
.chipbtn[aria-pressed="true"]{background:var(--ink); color:var(--bg); border-color:var(--ink)}
.chipbtn[aria-pressed="true"].f-good{background:var(--good); border-color:var(--good); color:#fff}
.chipbtn[aria-pressed="true"].f-warning{background:var(--warning); border-color:var(--warning); color:#1a1300}
.chipbtn[aria-pressed="true"].f-critical{background:var(--critical); border-color:var(--critical); color:#fff}
.chipbtn[aria-pressed="true"].f-skipped{background:var(--skipped); border-color:var(--skipped); color:#fff}

.layout{display:grid; grid-template-columns:200px 1fr; gap:2.5rem; align-items:start}
nav.cats{position:sticky; top:110px; display:flex; flex-direction:column; gap:.15rem; font-size:.85rem}
nav.cats a{
  color:var(--ink-2); text-decoration:none; padding:.35rem .6rem; border-radius:6px; border-left:2px solid transparent;
}
nav.cats a:hover{background:var(--surface-2)}
nav.cats a .c{float:right; color:var(--ink-muted); font-variant-numeric:tabular-nums; font-family:var(--font-mono); font-size:.78rem}

section.category{margin-bottom:2.25rem; scroll-margin-top:110px}
.cat-head{display:flex; align-items:baseline; justify-content:space-between; gap:1rem; flex-wrap:wrap; margin-bottom:.6rem}
.cat-head h2{font-family:var(--font-display); font-size:1.15rem; margin:0; font-weight:600}
.proportion{display:flex; gap:2px; height:6px; border-radius:3px; overflow:hidden; margin-top:.5rem; background:var(--grid)}
.proportion i{display:block; height:100%}
.proportion .p-good{background:var(--good)}
.proportion .p-warning{background:var(--warning)}
.proportion .p-critical{background:var(--critical)}
.proportion .p-skipped{background:var(--skipped)}

.tablewrap{overflow-x:auto; border:1px solid var(--border); border-radius:10px; background:var(--surface)}
table{border-collapse:collapse; width:100%; font-size:.85rem; min-width:720px}
thead th{
  text-align:left; padding:.55rem .8rem; background:var(--surface-2); color:var(--ink-muted);
  font-size:.72rem; text-transform:uppercase; letter-spacing:.05em; font-weight:600;
  border-bottom:1px solid var(--border); position:sticky; top:0;
}
tbody td{padding:.6rem .8rem; border-bottom:1px solid var(--grid); vertical-align:top}
tbody tr:last-child td{border-bottom:none}
tbody tr{border-left:3px solid transparent}
tbody tr.st-Healthy{border-left-color:var(--good)}
tbody tr.st-Warning{border-left-color:var(--warning)}
tbody tr.st-Critical{border-left-color:var(--critical)}
tbody tr.st-Skipped{border-left-color:var(--skipped)}
tbody tr.is-hidden{display:none}
td.target, td.check{font-family:var(--font-mono); font-size:.8rem; white-space:nowrap}
td.msg{color:var(--ink-2); max-width:340px}
td.rec{color:var(--ink-muted); max-width:320px; font-size:.8rem}

.chip{display:inline-flex; align-items:center; gap:.35rem; font-size:.78rem; font-weight:600; white-space:nowrap}
.chip .dot{width:8px;height:8px;border-radius:50%}
.st-healthy .dot{background:var(--good)}
.st-warning .dot{background:var(--warning)}
.st-critical .dot{background:var(--critical)}
.st-skipped .dot{background:var(--skipped)}
.st-healthy{color:var(--good)}
.st-warning{color:#9a6b00}
.st-critical{color:var(--critical)}
.st-skipped{color:var(--ink-muted)}
:root[data-theme="dark"] .st-warning, @media (prefers-color-scheme:dark){.st-warning{color:var(--warning)}}

footer.rpt{color:var(--ink-muted); font-size:.8rem; padding-top:2rem; border-top:1px solid var(--border); margin-top:1rem}

@media (max-width:820px){
  .layout{grid-template-columns:1fr}
  nav.cats{position:static; flex-direction:row; flex-wrap:wrap; top:auto}
}
@media (prefers-reduced-motion:reduce){
  .gauge .fill{transition:none}
}
'@

$Js = @'
(function(){
  var root = document.documentElement;
  var stored = localStorage.getItem('adehat-theme');
  if (stored) { root.setAttribute('data-theme', stored); }
  var toggle = document.getElementById('theme-toggle');
  function current(){
    var attr = root.getAttribute('data-theme');
    if (attr) return attr;
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }
  function paint(){ toggle.textContent = current() === 'dark' ? 'Light mode' : 'Dark mode'; }
  paint();
  toggle.addEventListener('click', function(){
    var next = current() === 'dark' ? 'light' : 'dark';
    root.setAttribute('data-theme', next);
    localStorage.setItem('adehat-theme', next);
    paint();
  });

  var rows = Array.prototype.slice.call(document.querySelectorAll('tbody tr[data-status]'));
  var buttons = Array.prototype.slice.call(document.querySelectorAll('.chipbtn'));
  var active = 'All';

  function applyFilter(){
    rows.forEach(function(r){
      var show = active === 'All' || r.getAttribute('data-status') === active;
      r.classList.toggle('is-hidden', !show);
    });
    buttons.forEach(function(b){ b.setAttribute('aria-pressed', b.dataset.filter === active ? 'true' : 'false'); });
  }

  buttons.forEach(function(b){
    b.addEventListener('click', function(){ active = b.dataset.filter; applyFilter(); });
  });
  applyFilter();
})();
'@

# ---------------------------------------------------------------
# Dynamic content
# ---------------------------------------------------------------

$Categories = $HealthResults | Group-Object -Property Category | Sort-Object Name

$NavLinks = foreach ($Category in $Categories) {
    $Anchor = ($Category.Name -replace '[^A-Za-z0-9]', '')
    "<a href=`"#cat-$Anchor`">$($Category.Name) <span class=`"c`">$($Category.Count)</span></a>"
}

$CategorySections = foreach ($Category in $Categories) {

    $Anchor = ($Category.Name -replace '[^A-Za-z0-9]', '')
    $Total = $Category.Count

    $Healthy  = @($Category.Group | Where-Object Status -eq 'Healthy').Count
    $Warning  = @($Category.Group | Where-Object Status -eq 'Warning').Count
    $Critical = @($Category.Group | Where-Object Status -eq 'Critical').Count
    $Skipped  = @($Category.Group | Where-Object Status -eq 'Skipped').Count

    $Segments = ""
    foreach ($seg in @(
        @{ n = $Healthy;  c = 'p-good' }
        @{ n = $Warning;  c = 'p-warning' }
        @{ n = $Critical; c = 'p-critical' }
        @{ n = $Skipped;  c = 'p-skipped' }
    )) {
        if ($seg.n -gt 0) {
            $Pct = [math]::Round(($seg.n / $Total) * 100, 2)
            $Segments += "<i class=`"$($seg.c)`" style=`"flex-basis:$Pct%`"></i>"
        }
    }

    $Rows = foreach ($Result in ($Category.Group | Sort-Object @{Expression={
                switch ($_.Status) { 'Critical' {0} 'Warning' {1} 'Skipped' {2} default {3} }
            }}, Target)) {
        @"
        <tr class="st-$($Result.Status)" data-status="$($Result.Status)">
            <td class="check">$(HtmlEncode $Result.Check)</td>
            <td class="target">$(HtmlEncode $Result.Target)</td>
            <td>$(Get-StatusChip $Result.Status)</td>
            <td class="msg">$(HtmlEncode $Result.Message)</td>
            <td class="rec">$(HtmlEncode $Result.Recommendation)</td>
        </tr>
"@
    }

    @"
    <section class="category" id="cat-$Anchor">
        <div class="cat-head">
            <h2>$($Category.Name)</h2>
            <span style="color:var(--ink-muted);font-size:.8rem">$Healthy healthy &middot; $Warning warning &middot; $Critical critical &middot; $Skipped skipped</span>
        </div>
        <div class="proportion">$Segments</div>
        <div class="tablewrap" style="margin-top:.75rem">
        <table>
            <thead>
                <tr><th>Check</th><th>Target</th><th>Status</th><th>Message</th><th>Recommendation</th></tr>
            </thead>
            <tbody>
                $($Rows -join "`n")
            </tbody>
        </table>
        </div>
    </section>
"@
}

$DashboardCards = foreach ($Category in $Categories) {

    $Anchor = ($Category.Name -replace '[^A-Za-z0-9]', '')
    $Total = $Category.Count

    $CatHealthy  = @($Category.Group | Where-Object Status -eq 'Healthy').Count
    $CatWarning  = @($Category.Group | Where-Object Status -eq 'Warning').Count
    $CatCritical = @($Category.Group | Where-Object Status -eq 'Critical').Count
    $CatSkipped  = @($Category.Group | Where-Object Status -eq 'Skipped').Count

    $HealthyPct = if ($Total -gt 0) { [math]::Round(($CatHealthy / $Total) * 100) } else { 0 }

    $ReviewClass = if ($CatCritical -gt 0) { 'rev-critical' }
                   elseif ($CatWarning -gt 0) { 'rev-warning' }
                   elseif ($CatSkipped -gt 0) { 'rev-skipped' }
                   else { 'rev-good' }

    $FlagHtml = if ($CatCritical -gt 0) { " &middot; <b class=`"crit`">$CatCritical critical</b>" }
                elseif ($CatWarning -gt 0) { " &middot; <b class=`"warn`">$CatWarning to review</b>" }
                else { " &middot; all clear" }

    @"
    <a class="dash-card" href="#cat-$Anchor">
      <div class="dash-donut">
        $(Get-DonutSvg -HealthyPercent $HealthyPct -ReviewClass $ReviewClass)
        <div class="dash-label"><span class="dash-pct">$HealthyPct%</span><span class="dash-sub">Healthy</span></div>
      </div>
      <div class="dash-name">$($Category.Name)</div>
      <div class="dash-count">$CatHealthy/$Total$FlagHtml</div>
    </a>
"@
}

# Spotlight: the most severe, deduplicated findings for an executive glance.
# Grouped by Category+Check+Message so (for example) "SMBv1 enabled on 29 DCs"
# renders as one card instead of 29 near-identical rows.
$SpotlightSource = $HealthResults | Where-Object { $_.Status -eq 'Critical' -or $_.Severity -eq 'High' }

$SpotlightGroups = $SpotlightSource |
    Group-Object -Property Category, Check, Message |
    Sort-Object `
        @{Expression = { switch ($_.Group[0].Status) { 'Critical' {0} 'Warning' {1} default {2} } }}, `
        @{Expression = { $_.Count }; Descending = $true }

$SpotlightCards = foreach ($Group in ($SpotlightGroups | Select-Object -First 8)) {

    $First = $Group.Group[0]
    $TargetLabel = if ($Group.Count -eq 1) { $First.Target } else { "$($Group.Count) targets affected" }

    @"
    <div class="spot-card spot-$($First.Status)">
      <div class="spot-top">
        <span class="spot-cat">$(HtmlEncode $First.Category)</span>
        $(Get-StatusChip $First.Status)
      </div>
      <div class="spot-check">$(HtmlEncode $First.Check)</div>
      <div class="spot-msg">$(HtmlEncode $First.Message)</div>
      <div class="spot-target">$(HtmlEncode $TargetLabel)</div>
    </div>
"@
}

if (-not $SpotlightCards) {
    $SpotlightCards = @('<p class="spot-empty">No critical or high-severity findings. The forest is in good shape.</p>')
}

$DCsByOS = $DCs | Group-Object -Property OperatingSystem | Sort-Object Count -Descending
$OSTotal = $DCs.Count
$OSRows = foreach ($Group in $DCsByOS) {
    $Pct = if ($OSTotal -gt 0) { [math]::Round(($Group.Count / $OSTotal) * 100, 1) } else { 0 }
    "<tr><td class=`"check`">$(HtmlEncode $Group.Name)</td><td class=`"target`">$($Group.Count)</td><td class=`"rec`">$Pct%</td></tr>"
}

# Score gauge geometry
$Radius = 54
$Circumference = [math]::Round(2 * [math]::PI * $Radius, 2)
$DashOffset = [math]::Round($Circumference * (1 - ([double]$Score.Score / 100)), 2)
$ScoreWord = if ($Score.Score -ge 90) { "Good" } elseif ($Score.Score -ge 70) { "Needs attention" } else { "At risk" }

$Html = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>AD Health Assessment - $(HtmlEncode $Forest.ForestName)</title>
<style>
$Css
</style>
</head>
<body>

<header class="top">
  <div class="row">
    <div class="masthead">
      <h1>Enterprise Active Directory Health Assessment</h1>
      <div class="meta"><b>$(HtmlEncode $Forest.ForestName)</b> &middot; generated $(Get-Date -Format "dd MMM yyyy, HH:mm")</div>
    </div>
    <button id="theme-toggle" class="theme-toggle" type="button">Dark mode</button>
  </div>
</header>

<div class="wrap">

  <div class="hero">
    <div class="gauge">
      <svg width="132" height="132" viewBox="0 0 132 132">
        <circle class="track" cx="66" cy="66" r="$Radius"></circle>
        <circle class="fill" cx="66" cy="66" r="$Radius"
          stroke-dasharray="$Circumference" stroke-dashoffset="$DashOffset"></circle>
      </svg>
      <div class="label">
        <div class="num">$($Score.Score)</div>
        <div class="of">of 100 &middot; $ScoreWord</div>
      </div>
    </div>

    <div class="stats">
      <div class="stat"><div class="n">$($DCs.Count)</div><div class="l">Domain Controllers</div></div>
      <div class="stat"><div class="n">$($Forest.DomainCount)</div><div class="l">Domains</div></div>
      <div class="stat"><div class="n">$($Forest.GlobalCatalogCount)</div><div class="l">Global Catalogs</div></div>
      <div class="stat good"><div class="n">$($Score.HealthyCount)</div><div class="l">Healthy</div></div>
      <div class="stat warning"><div class="n">$($Score.WarningCount)</div><div class="l">Warning</div></div>
      <div class="stat critical"><div class="n">$($Score.CriticalCount)</div><div class="l">Critical</div></div>
    </div>
  </div>

  <section class="dashboard" aria-label="Health by category">
    <h2 class="section-title">Health by Category</h2>
    <div class="dash-grid">
      $($DashboardCards -join "`n")
    </div>
  </section>

  <section class="spotlight" aria-label="Key findings">
    <h2 class="section-title">Key Findings</h2>
    <div class="spot-grid">
      $($SpotlightCards -join "`n")
    </div>
  </section>

  <div class="filterbar">
    Filter findings:
    <button class="chipbtn" data-filter="All" aria-pressed="true" type="button"><i class="dot"></i>All</button>
    <button class="chipbtn f-good" data-filter="Healthy" aria-pressed="false" type="button"><i class="dot"></i>Healthy</button>
    <button class="chipbtn f-warning" data-filter="Warning" aria-pressed="false" type="button"><i class="dot"></i>Warning</button>
    <button class="chipbtn f-critical" data-filter="Critical" aria-pressed="false" type="button"><i class="dot"></i>Critical</button>
    <button class="chipbtn f-skipped" data-filter="Skipped" aria-pressed="false" type="button"><i class="dot"></i>Skipped</button>
  </div>

  <div class="layout">
    <nav class="cats">
      <a href="#cat-Inventory">Inventory <span class="c">$($DCs.Count)</span></a>
      $($NavLinks -join "`n")
    </nav>

    <main>
      <section class="category" id="cat-Inventory">
        <div class="cat-head"><h2>Domain Controllers by Operating System</h2></div>
        <div class="tablewrap">
        <table>
          <thead><tr><th>Operating System</th><th>Count</th><th>Share</th></tr></thead>
          <tbody>
            $($OSRows -join "`n")
          </tbody>
        </table>
        </div>
      </section>

      $($CategorySections -join "`n")
    </main>
  </div>

  <footer class="rpt">
    Enterprise Active Directory Health Assessment Toolkit &middot; Walter Campal
  </footer>
</div>

<script>
$Js
</script>
</body>
</html>
"@

$Html | Out-File -FilePath $OutputPath -Encoding UTF8

Write-Host ""
Write-Host "HTML report exported: $OutputPath" -ForegroundColor Green

return $OutputPath
