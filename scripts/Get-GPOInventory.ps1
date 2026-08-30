<#
.SYNOPSIS
    Retrieves an inventory of all Group Policy Objects in the domain.

.DESCRIPTION
    Collects each GPO's name, status, links, and last modification date to
    help identify unlinked, disabled, or stale Group Policy Objects.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.1.0
#>

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Collecting Group Policy Object inventory..."

if (!(Test-RequiredModule -ModuleName GroupPolicy)) { return }

try {

    $GPOs = Get-GPO -All

    $GpoReport = foreach ($GPO in $GPOs) {

        [xml]$Report = Get-GPOReport -Guid $GPO.Id -ReportType Xml
        $Links = $Report.GPO.LinksTo | ForEach-Object { $_.SOMPath }

        [PSCustomObject]@{

            Name             = $GPO.DisplayName
            Id               = $GPO.Id
            GpoStatus        = $GPO.GpoStatus
            CreationTime     = $GPO.CreationTime
            ModificationTime = $GPO.ModificationTime
            LinkedTo         = ($Links -join ", ")
            LinkCount        = ($Links | Measure-Object).Count

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
