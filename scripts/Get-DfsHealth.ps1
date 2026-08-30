<#
.SYNOPSIS
    Assesses DFS Namespace health (independent of SYSVOL DFSR).

.DESCRIPTION
    Enumerates DFS Namespaces and their folder targets, flagging targets
    that are offline.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.1.0
#>

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Collecting DFS Namespace Health..."

if (!(Test-RequiredModule -ModuleName DFSN)) { return }

try {

    $Namespaces = Get-DfsnRoot

    $DfsReport = foreach ($Namespace in $Namespaces) {

        $Folders = Get-DfsnFolder -Path "$($Namespace.Path)\*" -ErrorAction SilentlyContinue

        foreach ($Folder in $Folders) {

            $Targets = Get-DfsnFolderTarget -Path $Folder.Path -ErrorAction SilentlyContinue

            foreach ($Target in $Targets) {

                [PSCustomObject]@{

                    Namespace   = $Namespace.Path
                    Folder      = $Folder.Path
                    TargetPath  = $Target.TargetPath
                    State       = $Target.State

                }

            }

        }

    }

    $DfsReport | Format-Table -AutoSize

    Export-AssessmentCsv -Data $DfsReport -Name "DfsNamespaceHealth"

    $Offline = $DfsReport | Where-Object { $_.State -ne "Online" }
    if ($Offline) {
        Write-WarningMessage "$($Offline.Count) DFS folder target(s) not Online."
    }

}
catch {
    Write-ErrorMessage "Failed to collect DFS Namespace Health: $($_.Exception.Message)"
}
