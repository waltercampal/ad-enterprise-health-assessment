<#
.SYNOPSIS
    Checks whether a given path (default: the Novell Identity Manager install
    folder) exists on every Domain Controller in the inventory.

.DESCRIPTION
    Reads the list of DCs from reports\DomainControllerInventory.csv (the
    output of Get-DomainControllerInventory.ps1) - or from -ComputerName if
    you pass your own list - and remotes into each one (WinRM/Invoke-Command)
    to run Test-Path against the target folder.

    Prompts for ONE credential PER DOMAIN instead of a single credential for
    everything: Invoke-Command/WinRM needs real local admin rights on the
    target machine, and an Enterprise Admin from the root domain doesn't
    necessarily have that on every child domain's DCs (unlike the AD/LDAP
    cmdlets used by the rest of this toolkit, which work forest-wide off the
    root domain's Enterprise Admin thanks to the trust). So this asks once
    per domain found among the targets (ccba.usr.bpba, filiales.usr.bpba,
    cmlp.usr.bpba, usr.bpba, ...) and uses the matching credential for each
    DC's Invoke-Command call.

    Built to run against 100+ DCs without hanging for hours on the ones that
    are unreachable: within each domain it fans out in parallel
    (-ThrottleLimit) and uses a short WinRM connection timeout so an
    offline/unreachable DC fails in seconds, not the default ~3 minutes.

    Results are printed to the console and exported to
    reports\NovellIdmPathCheck.csv.

.PARAMETER Credentials
    Optional hashtable of Domain -> PSCredential (e.g. from a prior run) to
    skip the interactive prompts, e.g.:
        @{ "ccba.usr.bpba" = $CcbaCred; "filiales.usr.bpba" = $FilialesCred }
    Any domain present in the targets but missing from this hashtable is
    still prompted for interactively.

.PARAMETER Path
    The path to check for on each DC. Defaults to the Novell Identity
    Manager install folder.

.PARAMETER InventoryCsv
    Path to DomainControllerInventory.csv. Defaults to reports\ under the
    repo root (..\reports relative to this script).

.PARAMETER ComputerName
    Optional explicit list of DC names/FQDNs to check instead of reading
    from -InventoryCsv. Domain is inferred from each name's suffix (e.g.
    DCCCBA20.ccba.usr.bpba -> ccba.usr.bpba) so per-domain credential
    prompting still works.

.PARAMETER ThrottleLimit
    Max DCs to query in parallel PER DOMAIN. Default 32.

.EXAMPLE
    .\Get-NovellIdmPathCheck.ps1

.EXAMPLE
    .\Get-NovellIdmPathCheck.ps1 -ComputerName DCCCBA20.ccba.usr.bpba, DCSUC20.filiales.usr.bpba

.AUTHOR
    Walter Campal

.VERSION
    1.1.0
#>

param(
    [hashtable]$Credentials = @{},
    [string]$Path = "C:\Program Files (x86)\Novell\Identity Manager",
    [string]$InventoryCsv = (Join-Path $PSScriptRoot "..\reports\DomainControllerInventory.csv"),
    [string[]]$ComputerName,
    [int]$ThrottleLimit = 32
)

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Checking for '$Path' across the Domain Controllers..."

# --- Build the target list, with a Domain on every entry -------------------

$DCInfoByName = @{}
$Targets = @()

if ($ComputerName) {
    foreach ($Name in ($ComputerName | Select-Object -Unique)) {
        # Infer the domain from the FQDN suffix (everything after the first
        # dot), e.g. DCCCBA20.ccba.usr.bpba -> ccba.usr.bpba. Falls back to
        # "(desconocido)" for a bare hostname with no dots.
        $DotIndex = $Name.IndexOf(".")
        $InferredDomain = if ($DotIndex -ge 0) { $Name.Substring($DotIndex + 1) } else { "(desconocido)" }
        $DCInfoByName[$Name] = [PSCustomObject]@{ Name = $Name; Domain = $InferredDomain; Site = "" }
        $Targets += $Name
    }
}
else {
    if (!(Test-Path $InventoryCsv)) {
        Write-ErrorMessage "Inventory file not found: $InventoryCsv. Run Get-DomainControllerInventory.ps1 first, pass -InventoryCsv, or pass -ComputerName directly."
        return
    }

    $Inventory = Import-Csv $InventoryCsv
    if (!$Inventory -or @($Inventory).Count -eq 0) {
        Write-ErrorMessage "No DCs found in $InventoryCsv"
        return
    }

    foreach ($row in $Inventory) {
        $DCInfoByName[$row.Name] = $row
    }
    $Targets = $Inventory | Select-Object -ExpandProperty Name -Unique
}

Write-Step "$($Targets.Count) DC(s) to check."

# --- Group targets by domain, prompting once per domain --------------------

$TargetsByDomain = $Targets | Group-Object { $DCInfoByName[$_].Domain }

Write-Step "Domains involved: $($TargetsByDomain.Name -join ', ')"

foreach ($Group in $TargetsByDomain) {
    $Domain = $Group.Name
    if (!$Credentials.ContainsKey($Domain)) {
        $Credentials[$Domain] = Get-Credential -Message "Credenciales con admin local en los DCs de '$Domain' (para chequear '$Path')"
    }
}

# --- Query each domain's DCs in parallel, with a short connection timeout --
# --- so unreachable DCs (offline, no WinRM, firewalled) fail fast ----------

$SessionOption = New-PSSessionOption -OpenTimeout 15000 -OperationTimeout 30000
$ResultByComputer = @{}
$ErrorByComputer = @{}

foreach ($Group in $TargetsByDomain) {
    $Domain = $Group.Name
    $DomainTargets = $Group.Group
    $Cred = $Credentials[$Domain]

    Write-Step "Querying $($DomainTargets.Count) DC(s) in '$Domain'..."

    $Results = Invoke-Command `
        -ComputerName $DomainTargets `
        -Credential $Cred `
        -ThrottleLimit $ThrottleLimit `
        -SessionOption $SessionOption `
        -ErrorAction SilentlyContinue `
        -ErrorVariable InvokeErrors `
        -ScriptBlock {
            param($TargetPath)

            $Exists = Test-Path -LiteralPath $TargetPath

            [PSCustomObject]@{
                PathExists = $Exists
                LastWrite  = if ($Exists) { (Get-Item -LiteralPath $TargetPath -ErrorAction SilentlyContinue).LastWriteTime } else { $null }
                ItemCount  = if ($Exists) { @(Get-ChildItem -LiteralPath $TargetPath -ErrorAction SilentlyContinue).Count } else { $null }
            }

        } -ArgumentList $Path

    foreach ($r in $Results) {
        $ResultByComputer[$r.PSComputerName] = $r
    }

    foreach ($e in $InvokeErrors) {
        $Target = $e.TargetObject
        if ($Target -and -not $ErrorByComputer.ContainsKey($Target)) {
            $ErrorByComputer[$Target] = $e.Exception.Message
        }
    }
}

# --- Assemble the final report ----------------------------------------------

$Report = foreach ($DC in $Targets) {

    $Info = $DCInfoByName[$DC]
    $Hit = $ResultByComputer[$DC]

    if ($Hit) {
        $Status = if ($Hit.PathExists) { "Existe" } else { "No existe" }
        $Detail = if ($Hit.PathExists) { "LastWrite=$($Hit.LastWrite) | Items=$($Hit.ItemCount)" } else { "" }
    }
    elseif ($ErrorByComputer.ContainsKey($DC)) {
        $Status = "Error de conexion"
        $Detail = $ErrorByComputer[$DC]
    }
    else {
        $Status = "Sin respuesta"
        $Detail = ""
    }

    [PSCustomObject]@{
        Name   = $DC
        Domain = if ($Info) { $Info.Domain } else { "" }
        Site   = if ($Info) { $Info.Site } else { "" }
        Status = $Status
        Detail = $Detail
    }

}

$Report | Sort-Object Status, Site, Name | Format-Table -AutoSize

Export-AssessmentCsv -Data $Report -Name "NovellIdmPathCheck"

# --- Summary -----------------------------------------------------------

$Existe = @($Report | Where-Object { $_.Status -eq "Existe" })
$NoExiste = @($Report | Where-Object { $_.Status -eq "No existe" })
$SinRespuesta = @($Report | Where-Object { $_.Status -in @("Error de conexion", "Sin respuesta") })

Write-Step "Resumen"
Write-Success "'$Path' EXISTE en $($Existe.Count) DC(s)."
if ($Existe.Count -gt 0) {
    $Existe | ForEach-Object { Write-Host "    $($_.Name)" -ForegroundColor Green }
}
Write-WarningMessage "'$Path' NO existe en $($NoExiste.Count) DC(s)."
if ($SinRespuesta.Count -gt 0) {
    Write-WarningMessage "$($SinRespuesta.Count) DC(s) no respondieron (WinRM inalcanzable / credenciales / firewall) - revisar 'Detail' en el CSV."
}
