<#
.SYNOPSIS
    Retrieves an inventory of all Group Policy Objects across every domain in the forest.

.DESCRIPTION
    Enumerates every domain in the forest and collects each one's GPOs —
    name, status, links, and last modification date — to help identify
    unlinked, disabled, or stale Group Policy Objects anywhere in the
    forest, not just in the domain the machine running this happens to be
    joined to.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.2.0
#>

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Collecting Group Policy Object inventory (all domains in the forest)..."

if (!(Test-RequiredModule -ModuleName GroupPolicy)) { return }
if (!(Test-RequiredModule -ModuleName ActiveDirectory)) { return }

try {

    $GpoReport = foreach ($DomainName in (Get-ForestDomains)) {

        try {

            $GPOs = Get-GPO -All -Domain $DomainName -ErrorAction Stop

            foreach ($GPO in $GPOs) {

                [xml]$Report = Get-GPOReport -Guid $GPO.Id -Domain $DomainName -ReportType Xml
                $Links = $Report.GPO.LinksTo | ForEach-Object { $_.SOMPath }

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
