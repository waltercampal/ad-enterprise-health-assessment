<#
.SYNOPSIS
    Retrieves an inventory of all Group Policy Objects across every domain in the forest.

.DESCRIPTION
    Enumerates every domain in the forest and collects each one's GPOs —
    name, status, links, and last modification date — to help identify
    unlinked, disabled, or stale Group Policy Objects anywhere in the
    forest, not just in the domain the machine running this happens to be
    joined to.

    Resolves links by reading the gPLink attribute directly off every
    linked container (2 fast LDAP queries per domain) instead of calling
    Get-GPOReport per GPO, which generates a full settings XML dump for
    every single GPO and is one of the slowest RSAT operations - on a
    forest with many GPOs, that could take minutes with no progress shown
    at all.

.PARAMETER Credential
    Optional alternate credential for the AD-based link lookup (Get-ADObject
    supports -Credential). The GroupPolicy module's own cmdlets (Get-GPO,
    Get-GPOReport) do NOT support alternate credentials at all - that part
    always runs as whichever account is running this script.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.4.0
#>

param(
    [PSCredential]$Credential
)

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Collecting Group Policy Object inventory (all domains in the forest)..."

if (!(Test-RequiredModule -ModuleName GroupPolicy)) { return }
if (!(Test-RequiredModule -ModuleName ActiveDirectory)) { return }

if ($Credential) {
    Write-WarningMessage "The GroupPolicy module (Get-GPO/Get-GPOReport) doesn't support alternate credentials - GPO metadata will be read as the account running this script. Only link resolution uses -Credential."
}

function Get-GpoLinksByGuid {
    param(
        [Parameter(Mandatory)][string]$DomainName,
        [PSCredential]$Credential
    )

    $AdParams = @{ ErrorAction = "Stop" }
    if ($Credential) { $AdParams["Credential"] = $Credential }

    # Every OU/domain root/site with at least one GPO linked to it carries a
    # gPLink attribute listing the linked GPOs' GUIDs. Reading that directly
    # is two fast LDAP queries per domain, vs. one slow Get-GPOReport call
    # per GPO.
    $LinkedContainers = Get-ADObject -LDAPFilter "(gPLink=*)" -Server $DomainName -Properties gPLink @AdParams

    $LinksByGuid = @{}

    foreach ($Container in $LinkedContainers) {

        $Matches = [regex]::Matches($Container.gPLink, '\[LDAP://cn=\{([0-9A-Fa-f-]+)\}[^;\]]*;\d+\]')

        foreach ($Match in $Matches) {
            $Guid = $Match.Groups[1].Value.ToUpper()
            if (!$LinksByGuid.ContainsKey($Guid)) {
                $LinksByGuid[$Guid] = @()
            }
            $LinksByGuid[$Guid] += $Container.DistinguishedName
        }

    }

    return $LinksByGuid
}

try {

    $GpoReport = foreach ($DomainName in (Get-ForestDomains -Credential $Credential)) {

        try {

            $GPOs = Get-GPO -All -Domain $DomainName -ErrorAction Stop
            Write-Step "  $DomainName`: $($GPOs.Count) GPO(s) found, resolving links..."

            $LinksByGuid = Get-GpoLinksByGuid -DomainName $DomainName -Credential $Credential

            foreach ($GPO in $GPOs) {

                $Links = $LinksByGuid[$GPO.Id.ToString().ToUpper()]

                [PSCustomObject]@{

                    Domain           = $DomainName
                    Name             = $GPO.DisplayName
                    Id               = $GPO.Id
                    GpoStatus        = $GPO.GpoStatus
                    CreationTime     = $GPO.CreationTime
                    ModificationTime = $GPO.ModificationTime
                    LinkedTo         = ($Links -join ", ")
                    LinkCount        = ($Links | Measure-Object).Count

                }

            }

        }
        catch {
            Write-WarningMessage "Could not query GPOs in domain '$DomainName': $($_.Exception.Message)"
        }

    }

    $GpoReport | Format-Table -AutoSize

    Export-AssessmentCsv -Data $GpoReport -Name "GPOInventory"

    $Unlinked = $GpoReport | Where-Object { $_.LinkCount -eq 0 }
    if ($Unlinked) {
        Write-WarningMessage "$($Unlinked.Count) GPO(s) are not linked to any OU, domain, or site."
    }

}
catch {
    Write-ErrorMessage "Failed to collect GPO inventory: $($_.Exception.Message)"
}
