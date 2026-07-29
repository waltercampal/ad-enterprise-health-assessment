<#
.SYNOPSIS
    Runs the complete Enterprise Active Directory Health Assessment.

.PARAMETER Credential
    Optional alternate credential used for every AD/WinRM/CIM operation in
    this run (Discovery and Health modules alike). If omitted, the current
    user's session identity is used, as before.

.PARAMETER CredentialPath
    Optional path to a credential previously saved with
    `Get-Credential | Export-Clixml -Path <path>`. Loaded via Import-Clixml
    (DPAPI-protected - only decryptable by the same user on the same
    machine that exported it). Ignored if -Credential is also supplied.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    2.1.0
#>

param(
    [System.Management.Automation.PSCredential]$Credential,
    [string]$CredentialPath
)

if (-not $Credential -and $CredentialPath) {
    if (-not (Test-Path $CredentialPath)) {
        throw "CredentialPath '$CredentialPath' was not found."
    }
    $Credential = Import-Clixml -Path $CredentialPath
}

$CredSplat = if ($Credential) { @{ Credential = $Credential } } else { @{} }

Import-Module ActiveDirectory
Import-Module GroupPolicy -ErrorAction SilentlyContinue

# ------------------------------------------------------------
# Load Common Functions
# ------------------------------------------------------------

. .\scripts\Common\Common.ps1

# ------------------------------------------------------------
# Load Health Modules
# ------------------------------------------------------------

Get-ChildItem -Path .\scripts\Health\*.ps1 | ForEach-Object {
    . $_.FullName
}

# ------------------------------------------------------------
# Banner
# ------------------------------------------------------------

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Enterprise AD Health Assessment" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------
# Discovery
# ------------------------------------------------------------

Write-Step "Running Discovery modules..."

$Forest  = .\scripts\Get-ForestInformation.ps1 @CredSplat

if (-not $Forest) {
    Write-ErrorMessage "Discovery failed: Get-ForestInformation.ps1 returned nothing. Check credentials (domain-qualified username, e.g. DOMAIN\user or user@domain) and connectivity, then re-run."
    exit 1
}

$Domains = .\scripts\Get-DomainInformation.ps1 @CredSplat
$FSMO    = .\scripts\Get-FSMORoles.ps1 @CredSplat
$DCs     = .\scripts\Get-DomainControllerInventory.ps1 @CredSplat
$Sites   = .\scripts\Get-SitesInformation.ps1 @CredSplat

if (-not $DCs) {
    Write-ErrorMessage "Discovery failed: Get-DomainControllerInventory.ps1 returned nothing. Check credentials and connectivity, then re-run."
    exit 1
}

# ------------------------------------------------------------
# Export Discovery
# ------------------------------------------------------------

Write-Step "Exporting Discovery results..."

Export-AssessmentCsv -Data $Forest  -Name "ForestInformation"
Export-AssessmentCsv -Data $Domains -Name "DomainInformation"
Export-AssessmentCsv -Data $FSMO    -Name "FSMORoles"
Export-AssessmentCsv -Data $DCs     -Name "DomainControllerInventory"
Export-AssessmentCsv -Data $Sites   -Name "SitesInformation"

# ------------------------------------------------------------
# Health
# ------------------------------------------------------------

Write-Step "Running Health modules..."

$Replication        = Get-HLReplicationHealth   -DomainControllers $DCs @CredSplat
$DNSHealth           = Get-HLDNSHealth            -DomainControllers $DCs @CredSplat
$TimeHealth          = Get-HLTimeHealth           -DomainControllers $DCs @CredSplat
$SysvolHealth        = Get-HLSysvolHealth         -DomainControllers $DCs @CredSplat
$GPOHealth           = Get-HLGPOHealth            -Domains $Domains
$SecurityBaseline    = Get-HLSecurityBaseline      -DomainControllers $DCs -Domains $Domains @CredSplat
$ServerConfig        = Get-HLServerConfig         -DomainControllers $DCs @CredSplat
$EventLogHealth      = Get-HLEventLogHealth       -DomainControllers $DCs
$MigrationReadiness  = Get-HLMigrationReadiness   -Forest $Forest -DomainControllers $DCs @CredSplat

$HealthResults = @(
    $Replication
    $DNSHealth
    $TimeHealth
    $SysvolHealth
    $GPOHealth
    $SecurityBaseline
    $ServerConfig
    $EventLogHealth
    $MigrationReadiness
)

# ------------------------------------------------------------
# Export Health
# ------------------------------------------------------------

Write-Step "Exporting Health results..."

Export-AssessmentCsv -Data $Replication       -Name "ReplicationHealth"
Export-AssessmentCsv -Data $DNSHealth          -Name "DNSHealth"
Export-AssessmentCsv -Data $TimeHealth         -Name "TimeHealth"
Export-AssessmentCsv -Data $SysvolHealth       -Name "SysvolHealth"
Export-AssessmentCsv -Data $GPOHealth          -Name "GPOHealth"
Export-AssessmentCsv -Data $SecurityBaseline   -Name "SecurityBaseline"
Export-AssessmentCsv -Data $ServerConfig       -Name "ServerConfig"
Export-AssessmentCsv -Data $EventLogHealth     -Name "EventLogHealth"
Export-AssessmentCsv -Data $MigrationReadiness -Name "MigrationReadiness"

# ------------------------------------------------------------
# Infrastructure Score
# ------------------------------------------------------------

Write-Step "Calculating Infrastructure Score..."

$Score = .\scripts\Reporting\Get-InfrastructureScore.ps1 -HealthResults $HealthResults

# ------------------------------------------------------------
# HTML Report
# ------------------------------------------------------------

Write-Step "Generating HTML report..."

.\scripts\Reporting\Get-HTMLReport.ps1 `
    -Forest $Forest `
    -DCs $DCs `
    -HealthResults $HealthResults `
    -Score $Score `
    | Out-Null

# ------------------------------------------------------------
# Executive Summary
# ------------------------------------------------------------

Write-Step "Generating Executive Summary..."

$Summary = .\scripts\Reporting\Get-ExecutiveSummary.ps1 `
    -Forest $Forest `
    -FSMO $FSMO `
    -DCs $DCs `
    -HealthResults $HealthResults `
    -Score $Score

# ------------------------------------------------------------
# Finish
# ------------------------------------------------------------

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host " Assessment completed successfully." -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""

Write-Host "Forest............... $($Forest.ForestName)"
Write-Host "Domains.............. $($Forest.DomainCount)"
Write-Host "Domain Controllers... $($DCs.Count)"
Write-Host "Sites................ $($Sites.Count)"
Write-Host "Health Checks Run.... $($HealthResults.Count)"
Write-Host "Infrastructure Score. $($Score.Score) / 100"

Write-Host ""

Write-Success "Enterprise Active Directory Health Assessment completed."
