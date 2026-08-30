<#
.SYNOPSIS
    Shared helper functions for the Enterprise Active Directory Health Assessment Toolkit.

.DESCRIPTION
    Provides consistent console output, module availability checks, and CSV export
    behavior for every assessment module in scripts/.

.AUTHOR
    Walter Campal
    Horizon Labs
#>

# Repo root = two levels up from scripts\Common
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$ReportsPath = Join-Path $RepoRoot "reports"

function Write-Step {

    param(
        [string]$Message
    )

    Write-Host ""
    Write-Host "[INFO] $Message" -ForegroundColor Cyan

}

function Write-Success {

    param(
        [string]$Message
    )

    Write-Host "[OK] $Message" -ForegroundColor Green

}

function Write-ErrorMessage {

    param(
        [string]$Message
    )

    Write-Host "[ERROR] $Message" -ForegroundColor Red

}

function Write-WarningMessage {

    param(
        [string]$Message
    )

    Write-Host "[WARN] $Message" -ForegroundColor Yellow

}

function Initialize-ReportsFolder {

    if (!(Test-Path $ReportsPath)) {
        New-Item -ItemType Directory -Path $ReportsPath -Force | Out-Null
    }

}

function Test-RequiredModule {

    param(
        [Parameter(Mandatory)]
        [string]$ModuleName
    )

    if (!(Get-Module -ListAvailable -Name $ModuleName)) {
        Write-WarningMessage "Module '$ModuleName' is not available on this system. Skipping this check."
        return $false
    }

    try {
        Import-Module $ModuleName -ErrorAction Stop
        return $true
    }
    catch {
        Write-ErrorMessage "Failed to import module '$ModuleName': $($_.Exception.Message)"
        return $false
    }

}

function Export-AssessmentCsv {

    param(

        [Parameter(Mandatory)]
        $Data,

        [Parameter(Mandatory)]
        [string]$Name

    )

    Initialize-ReportsFolder

    $Path = Join-Path $ReportsPath "$Name.csv"

    $Data |
    Export-Csv `
        -Path $Path `
        -NoTypeInformation `
        -Encoding UTF8

    Write-Success "Exported: $Path"

}
