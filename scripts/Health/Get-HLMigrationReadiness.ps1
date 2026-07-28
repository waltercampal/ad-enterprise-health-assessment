<#
.SYNOPSIS
    Retrieves Windows Server 2016 -> 2022 migration readiness checks: schema
    version, legacy OS blockers, functional levels, and additional server
    roles co-located on existing Domain Controllers.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    1.0.0
#>

function Get-HLMigrationReadiness {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Forest,

        [Parameter(Mandatory)]
        [array]$DomainControllers
    )

    $Results = @()

    # Minimum AD schema objectVersion required to introduce a Windows Server
    # 2022 Domain Controller (adprep /forestprep target).
    $RequiredSchemaVersion = 88

    #--------------------------------------------------
    # Schema version
    #--------------------------------------------------

    try {
        $RootDSE = Get-ADRootDSE -Server $Forest.SchemaMaster -ErrorAction Stop

        $SchemaVersion = (Get-ADObject `
            -Identity $RootDSE.schemaNamingContext `
            -Property objectVersion `
            -Server $Forest.SchemaMaster `
            -ErrorAction Stop).objectVersion

        if ($SchemaVersion -ge $RequiredSchemaVersion) {
            $Results += New-HealthResult `
                -Category "MigrationReadiness" `
                -Check "Schema Version" `
                -Target $Forest.Name `
                -Status Healthy `
                -Severity Info `
                -Message "Schema objectVersion $SchemaVersion detected. Meets the minimum required for Windows Server 2022 ($RequiredSchemaVersion)."
        }
        else {
            $Results += New-HealthResult `
                -Category "MigrationReadiness" `
                -Check "Schema Version" `
                -Target $Forest.Name `
                -Status Warning `
                -Severity High `
                -Message "Schema objectVersion $SchemaVersion detected. Windows Server 2022 requires $RequiredSchemaVersion." `
                -Recommendation "Run adprep /forestprep and adprep /domainprep /gpprep from Windows Server 2022 installation media (as Schema Admins/Enterprise Admins) before introducing the first 2022 Domain Controller."
        }
    }
    catch {
        $Results += New-HealthResult `
            -Category "MigrationReadiness" `
            -Check "Schema Version" `
            -Target $Forest.Name `
            -Status Warning `
            -Severity Medium `
            -Message $_.Exception.Message `
            -Recommendation "Verify connectivity to the Schema Master ($($Forest.SchemaMaster)) and re-run this check."
    }

    #--------------------------------------------------
    # Legacy OS Domain Controllers (2008 / 2008 R2)
    #--------------------------------------------------

    $LegacyDCs = $DomainControllers | Where-Object {
        $_.OperatingSystem -match '2008'
    }

    if ($LegacyDCs) {
        $Results += New-HealthResult `
            -Category "MigrationReadiness" `
            -Check "Legacy OS Domain Controllers" `
            -Target "Forest: $($Forest.Name)" `
            -Status Critical `
            -Severity High `
            -Message "$($LegacyDCs.Count) Domain Controller(s) still running Windows Server 2008/2008 R2: $($LegacyDCs.HostName -join ', ')." `
            -Recommendation "Windows Server 2022 cannot be introduced into a domain that still has Windows Server 2008/2008 R2 Domain Controllers. Decommission or upgrade these first."
    }
    else {
        $Results += New-HealthResult `
            -Category "MigrationReadiness" `
            -Check "Legacy OS Domain Controllers" `
            -Target "Forest: $($Forest.Name)" `
            -Status Healthy `
            -Severity Info `
            -Message "No Windows Server 2008 / 2008 R2 Domain Controllers found."
    }

    #--------------------------------------------------
    # Forest / Domain functional level
    #--------------------------------------------------

    $Results += New-HealthResult `
        -Category "MigrationReadiness" `
        -Check "Forest Functional Level" `
        -Target $Forest.Name `
        -Status Healthy `
        -Severity Info `
        -Message "Forest functional level: $($Forest.ForestMode). Already meets the minimum for Windows Server 2022 Domain Controllers (Windows Server 2008 or higher)."

    #--------------------------------------------------
    # Additional server roles on existing Domain Controllers
    #--------------------------------------------------

    $RolesOfInterest = 'ADCS-Cert-Authority', 'DHCP', 'NPAS'

    foreach ($DC in $DomainControllers) {

        Write-Verbose "Checking co-located server roles on $($DC.HostName)"

        try {
            $InstalledRoles = Invoke-Command -ComputerName $DC.HostName {
                param($RolesOfInterest)
                Get-WindowsFeature | Where-Object {
                    $_.Installed -and $_.Name -in $RolesOfInterest
                }
            } -ArgumentList (, $RolesOfInterest) -ErrorAction Stop

            if ($InstalledRoles) {
                $Results += New-HealthResult `
                    -Category "MigrationReadiness" `
                    -Check "Additional Server Roles on DCs" `
                    -Target $DC.HostName `
                    -Status Warning `
                    -Severity Medium `
                    -Message "Co-located role(s) detected: $($InstalledRoles.Name -join ', ')." `
                    -Recommendation "Plan a dedicated migration for this role before decommissioning the Domain Controller (e.g. Enterprise CA migration guidance, DHCP failover re-scope, or NPS/RADIUS config export)."
            }
            else {
                $Results += New-HealthResult `
                    -Category "MigrationReadiness" `
                    -Check "Additional Server Roles on DCs" `
                    -Target $DC.HostName `
                    -Status Healthy `
                    -Severity Info `
                    -Message "No additional server roles detected (DHCP, ADCS, NPS) beyond AD DS/DNS."
            }
        }
        catch {
            $Results += New-HealthResult `
                -Category "MigrationReadiness" `
                -Check "Additional Server Roles on DCs" `
                -Target $DC.HostName `
                -Status Warning `
                -Severity Low `
                -Message $_.Exception.Message `
                -Recommendation "Verify WinRM/connectivity to this Domain Controller and re-run this check."
        }
    }

    #--------------------------------------------------
    # RODC readiness note
    #--------------------------------------------------

    foreach ($RODC in ($DomainControllers | Where-Object IsReadOnly)) {
        $Results += New-HealthResult `
            -Category "MigrationReadiness" `
            -Check "RODC Readiness" `
            -Target $RODC.HostName `
            -Status Healthy `
            -Severity Info `
            -Message "Read-Only Domain Controller identified at site '$($RODC.Site)'." `
            -Recommendation "Confirm the replica-source Domain Controller and Password Replication Policy before staging its Windows Server 2022 replacement."
    }

    return $Results
}
