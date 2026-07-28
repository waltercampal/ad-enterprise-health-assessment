<#
.SYNOPSIS
    Retrieves Group Policy health: SYSVOL/AD version consistency and orphaned
    (unlinked) GPOs, for every domain in the forest.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    1.0.0
#>

function Get-HLGPOHealth {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Domains
    )

    $Results = @()

    foreach ($Domain in $Domains) {

        Write-Verbose "Checking Group Policy health on $($Domain.DomainName)"

        try {
            $GPOs = Get-GPO -All -Domain $Domain.DomainName -ErrorAction Stop
        }
        catch {
            $Results += New-HealthResult `
                -Category "GroupPolicy" `
                -Check "GPO Enumeration" `
                -Target $Domain.DomainName `
                -Status Warning `
                -Severity Medium `
                -Message $_.Exception.Message `
                -Recommendation "Verify the GroupPolicy module is available and the domain is reachable, then re-run this check."
            continue
        }

        foreach ($GPO in $GPOs) {

            $DisplayTarget = "$($GPO.DisplayName) ($($Domain.DomainName))"

            #--------------------------------------------------
            # SYSVOL vs Active Directory version consistency
            #--------------------------------------------------

            if ($GPO.User.SysvolVersion -eq $GPO.User.DSVersion -and
                $GPO.Computer.SysvolVersion -eq $GPO.Computer.DSVersion) {

                $Results += New-HealthResult `
                    -Category "GroupPolicy" `
                    -Check "GPO Version Consistency" `
                    -Target $DisplayTarget `
                    -Status Healthy `
                    -Severity Info `
                    -Message "SYSVOL version matches Active Directory version."
            }
            else {
                $Results += New-HealthResult `
                    -Category "GroupPolicy" `
                    -Check "GPO Version Consistency" `
                    -Target $DisplayTarget `
                    -Status Warning `
                    -Severity Medium `
                    -Message "AD version (User=$($GPO.User.DSVersion), Computer=$($GPO.Computer.DSVersion)) does not match SYSVOL version (User=$($GPO.User.SysvolVersion), Computer=$($GPO.Computer.SysvolVersion))." `
                    -Recommendation "Confirm SYSVOL replication is not backlogged for this domain before relying on this GPO."
            }

            #--------------------------------------------------
            # Orphaned (unlinked) GPO
            #--------------------------------------------------

            try {
                [xml]$Report = Get-GPOReport -Guid $GPO.Id -ReportType XML -ErrorAction Stop

                if (-not $Report.GPO.LinksTo) {
                    $Results += New-HealthResult `
                        -Category "GroupPolicy" `
                        -Check "Orphaned GPO" `
                        -Target $DisplayTarget `
                        -Status Warning `
                        -Severity Low `
                        -Message "GPO exists in SYSVOL and Active Directory but is not linked to any OU, domain or site." `
                        -Recommendation "Review with the domain owner; remove if obsolete to reduce SYSVOL replication overhead and simplify the migration cutover."
                }
            }
            catch {
                Write-Verbose "Could not evaluate GPO links for $DisplayTarget`: $($_.Exception.Message)"
            }
        }
    }

    return $Results
}
