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

    if (Get-Module -ListAvailable -Name $ModuleName) {
        try {
            Import-Module $ModuleName -ErrorAction Stop
            return $true
        }
        catch {
            Write-ErrorMessage "Failed to import module '$ModuleName': $($_.Exception.Message)"
            return $false
        }
    }

    # Some RSAT modules (e.g. GroupPolicy) aren't on PowerShell 7's own module
    # path and, unlike ActiveDirectory, aren't on its default auto-compat
    # list either - so Get-Module -ListAvailable finds nothing even when the
    # RSAT feature is installed. Try loading them explicitly through the
    # Windows PowerShell Compatibility layer before giving up.
    if ($PSVersionTable.PSEdition -eq "Core") {
        try {
            Import-Module $ModuleName -UseWindowsPowerShell -ErrorAction Stop -WarningAction SilentlyContinue
            return $true
        }
        catch {
            # Fall through to the warning below.
        }
    }

    Write-WarningMessage "Module '$ModuleName' is not available on this system. Skipping this check."
    return $false

}

function Get-ForestDomains {

    <#
    .SYNOPSIS
        Returns the DNS name of every domain in the current forest.

    .DESCRIPTION
        Used so assessment modules cover the whole forest (root domain +
        every child/tree domain) instead of only the domain the machine
        running the assessment happens to be joined to.

    .PARAMETER Credential
        Optional alternate credential to enumerate the forest with.
    #>

    param(
        [PSCredential]$Credential
    )

    $AdParams = @{ ErrorAction = "Stop" }
    if ($Credential) { $AdParams["Credential"] = $Credential }

    try {
        return @((Get-ADForest @AdParams).Domains)
    }
    catch {
        Write-ErrorMessage "Failed to enumerate forest domains, falling back to the current domain only: $($_.Exception.Message)"
        try {
            return @((Get-ADDomain @AdParams).DNSRoot)
        }
        catch {
            return @()
        }
    }

}

function Get-ForestDomainControllers {

    <#
    .SYNOPSIS
        Returns every Domain Controller across every domain in the forest.

    .DESCRIPTION
        Get-ADDomainController -Filter * with no -Server only returns DCs in
        the caller's own domain. This enumerates every domain in the forest
        (via Get-ForestDomains) and queries each one explicitly, so the
        assessment covers the root domain and every child domain rather than
        just the domain the machine running it happens to be joined to.

    .PARAMETER Credential
        Optional alternate credential to query every domain with.
    #>

    param(
        [PSCredential]$Credential
    )

    $AdParams = @{ Filter = "*"; ErrorAction = "Stop" }
    if ($Credential) { $AdParams["Credential"] = $Credential }

    $AllDCs = foreach ($DomainName in (Get-ForestDomains -Credential $Credential)) {
        try {
            Get-ADDomainController @AdParams -Server $DomainName
        }
        catch {
            Write-WarningMessage "Could not enumerate Domain Controllers in domain '$DomainName': $($_.Exception.Message)"
        }
    }

    return @($AllDCs)

}

function Export-AssessmentCsv {

    param(

        # Not [Parameter(Mandatory)]: when every item in a $DomainName in
        # (foreach ...) { ... } loop hits its catch block, PowerShell yields
        # $null rather than an empty array, and a mandatory parameter rejects
        # $null outright - crashing the whole module even though "zero
        # servers were reachable" is exactly the kind of finding this
        # toolkit exists to report, not something to crash on.
        [AllowNull()]
        $Data,

        [Parameter(Mandatory)]
        [string]$Name

    )

    if ($null -eq $Data -or @($Data).Count -eq 0) {
        Write-WarningMessage "No data collected for '$Name' - every query failed or returned nothing. Skipping CSV export."
        return
    }

    Initialize-ReportsFolder

    $Path = Join-Path $ReportsPath "$Name.csv"

    $Data |
    Export-Csv `
        -Path $Path `
        -NoTypeInformation `
        -Encoding UTF8

    Write-Success "Exported: $Path"

}
