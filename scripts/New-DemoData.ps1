<#
.SYNOPSIS
    Generates fictitious Active Directory assessment data for demo/portfolio use.

.DESCRIPTION
    Populates reports/*.csv with the exact same schema every real assessment
    module produces, but filled with fabricated data for a fictitious
    company ("Contoso Manufacturing"). Use this to showcase the toolkit and
    the HTML dashboard (New-AssessmentDashboard.ps1) without touching a real
    Active Directory environment — ideal for a public portfolio repository.

    A handful of findings are intentionally seeded (low disk space, a stale
    unlinked GPO, a lagging replication partner, etc.) so the resulting
    report looks like a real-world assessment instead of an unrealistic
    all-green environment.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.1.0
#>

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Generating fictitious demo data (Contoso Manufacturing)..."

Initialize-ReportsFolder

$Now = Get-Date

# ---------------------------------------------------------------------------
# Forest / Domain / FSMO
# ---------------------------------------------------------------------------

Export-AssessmentCsv -Name "ForestInformation" -Data ([PSCustomObject]@{
    ForestName     = "contoso.local"
    ForestMode     = "Windows2016Forest"
    RootDomain     = "contoso.local"
    Domains        = "contoso.local, emea.contoso.local"
    Sites          = "HQ-BuenosAires, DR-Cordoba, Branch-Rosario, Azure-EastUS"
    GlobalCatalogs = 4
    UPNSuffixes    = "contoso.com"
})

Export-AssessmentCsv -Name "DomainInformation" -Data ([PSCustomObject]@{
    DomainName           = "contoso.local"
    NetBIOSName          = "CONTOSO"
    DomainMode           = "Windows2016Domain"
    DistinguishedName    = "DC=contoso,DC=local"
    ParentDomain         = $null
    PDCEmulator          = "CONTOSO-DC01.contoso.local"
    RIDMaster            = "CONTOSO-DC01.contoso.local"
    InfrastructureMaster = "CONTOSO-DC02.contoso.local"
})

Export-AssessmentCsv -Name "FSMORoles" -Data ([PSCustomObject]@{
    SchemaMaster         = "CONTOSO-DC01.contoso.local"
    DomainNamingMaster   = "CONTOSO-DC01.contoso.local"
    PDCEmulator          = "CONTOSO-DC01.contoso.local"
    RIDMaster            = "CONTOSO-DC01.contoso.local"
    InfrastructureMaster = "CONTOSO-DC02.contoso.local"
})

# ---------------------------------------------------------------------------
# Domain Controller Inventory
# ---------------------------------------------------------------------------

$DCs = @(
    @{ Name = "CONTOSO-DC01.contoso.local"; Site = "HQ-BuenosAires"; IP = "10.10.1.10"; OS = "Windows Server 2022 Datacenter"; GC = $true;  RO = $false; Online = "Yes" }
    @{ Name = "CONTOSO-DC02.contoso.local"; Site = "HQ-BuenosAires"; IP = "10.10.1.11"; OS = "Windows Server 2022 Datacenter"; GC = $true;  RO = $false; Online = "Yes" }
    @{ Name = "CONTOSO-DC03.contoso.local"; Site = "DR-Cordoba";     IP = "10.20.1.10"; OS = "Windows Server 2019 Datacenter"; GC = $true;  RO = $false; Online = "Yes" }
    @{ Name = "CONTOSO-DC04.contoso.local"; Site = "Branch-Rosario"; IP = "10.30.1.10"; OS = "Windows Server 2016 Standard";   GC = $false; RO = $true;  Online = "No"  }
)

Export-AssessmentCsv -Name "DomainControllerInventory" -Data ($DCs | ForEach-Object {
    [PSCustomObject]@{
        Name            = $_.Name
        Domain          = "contoso.local"
        Site            = $_.Site
        IPv4Address     = $_.IP
        OperatingSystem = $_.OS
        GlobalCatalog   = $_.GC
        ReadOnly        = $_.RO
        Online          = $_.Online
    }
})

# ---------------------------------------------------------------------------
# Site Topology
# ---------------------------------------------------------------------------

Export-AssessmentCsv -Name "SiteTopology" -Data @(
    [PSCustomObject]@{ SiteName = "HQ-BuenosAires"; Description = "Headquarters";      SubnetCount = 2; Subnets = "10.10.1.0/24, 10.10.2.0/24" }
    [PSCustomObject]@{ SiteName = "DR-Cordoba";      Description = "Disaster Recovery"; SubnetCount = 1; Subnets = "10.20.1.0/24" }
    [PSCustomObject]@{ SiteName = "Branch-Rosario";  Description = "Branch Office";      SubnetCount = 1; Subnets = "10.30.1.0/24" }
    [PSCustomObject]@{ SiteName = "Azure-EastUS";    Description = "Cloud IaaS";         SubnetCount = 1; Subnets = "10.40.0.0/24" }
)

Export-AssessmentCsv -Name "SiteLinks" -Data @(
    [PSCustomObject]@{ SiteLinkName = "HQ-DR-Link";     Cost = 100; ReplicationIntervalMin = 15;  SitesIncluded = "HQ-BuenosAires, DR-Cordoba" }
    [PSCustomObject]@{ SiteLinkName = "HQ-Branch-Link"; Cost = 200; ReplicationIntervalMin = 180; SitesIncluded = "HQ-BuenosAires, Branch-Rosario" }
    [PSCustomObject]@{ SiteLinkName = "HQ-Azure-Link";  Cost = 50;  ReplicationIntervalMin = 15;  SitesIncluded = "HQ-BuenosAires, Azure-EastUS" }
)

# ---------------------------------------------------------------------------
# Replication Status
# ---------------------------------------------------------------------------

Export-AssessmentCsv -Name "ReplicationStatus" -Data @(
    [PSCustomObject]@{ Server = "CONTOSO-DC01.contoso.local"; Partner = "CONTOSO-DC02.contoso.local"; Partition = "DC=contoso,DC=local"; LastReplicationSuccess = $Now.AddMinutes(-12); LastReplicationResult = 0; ConsecutiveReplicationFailures = 0; Status = "OK" }
    [PSCustomObject]@{ Server = "CONTOSO-DC01.contoso.local"; Partner = "CONTOSO-DC03.contoso.local"; Partition = "DC=contoso,DC=local"; LastReplicationSuccess = $Now.AddMinutes(-14); LastReplicationResult = 0; ConsecutiveReplicationFailures = 0; Status = "OK" }
    [PSCustomObject]@{ Server = "CONTOSO-DC02.contoso.local"; Partner = "CONTOSO-DC04.contoso.local"; Partition = "DC=contoso,DC=local"; LastReplicationSuccess = $Now.AddHours(-19); LastReplicationResult = 8524; ConsecutiveReplicationFailures = 6; Status = "FAILURE" }
)

# ---------------------------------------------------------------------------
# SYSVOL / DFSR Health
# ---------------------------------------------------------------------------

Export-AssessmentCsv -Name "SysvolHealth" -Data @(
    [PSCustomObject]@{ Server = "CONTOSO-DC01.contoso.local"; State = "Normal"; Note = "" }
    [PSCustomObject]@{ Server = "CONTOSO-DC02.contoso.local"; State = "Normal"; Note = "" }
    [PSCustomObject]@{ Server = "CONTOSO-DC03.contoso.local"; State = "Normal"; Note = "" }
    [PSCustomObject]@{ Server = "CONTOSO-DC04.contoso.local"; State = "Auto Recovery"; Note = "Branch DC recovering after WAN outage." }
)

# ---------------------------------------------------------------------------
# DNS
# ---------------------------------------------------------------------------

Export-AssessmentCsv -Name "DnsZones" -Data @(
    [PSCustomObject]@{ Server = "CONTOSO-DC01.contoso.local"; ZoneName = "contoso.local";              ZoneType = "Primary"; IsDsIntegrated = $true;  IsSigned = $false; Dynamic = "Secure" }
    [PSCustomObject]@{ Server = "CONTOSO-DC01.contoso.local"; ZoneName = "_msdcs.contoso.local";        ZoneType = "Primary"; IsDsIntegrated = $true;  IsSigned = $false; Dynamic = "Secure" }
    [PSCustomObject]@{ Server = "CONTOSO-DC01.contoso.local"; ZoneName = "10.10.in-addr.arpa";          ZoneType = "Primary"; IsDsIntegrated = $true;  IsSigned = $false; Dynamic = "Secure" }
)

Export-AssessmentCsv -Name "DnsServers" -Data @(
    [PSCustomObject]@{ Server = "CONTOSO-DC01.contoso.local"; Forwarders = "8.8.8.8, 1.1.1.1"; ScavengingEnabled = $true;  RefreshInterval = "7.00:00:00"; NoRefreshInterval = "7.00:00:00" }
    [PSCustomObject]@{ Server = "CONTOSO-DC02.contoso.local"; Forwarders = "8.8.8.8, 1.1.1.1"; ScavengingEnabled = $false; RefreshInterval = "7.00:00:00"; NoRefreshInterval = "7.00:00:00" }
)

# ---------------------------------------------------------------------------
# GPO Inventory
# ---------------------------------------------------------------------------

Export-AssessmentCsv -Name "GPOInventory" -Data @(
    [PSCustomObject]@{ Name = "Default Domain Policy";        Id = (New-Guid); GpoStatus = "AllSettingsEnabled"; CreationTime = $Now.AddYears(-6); ModificationTime = $Now.AddMonths(-8); LinkedTo = "DC=contoso,DC=local"; LinkCount = 1 }
    [PSCustomObject]@{ Name = "Workstation Security Baseline"; Id = (New-Guid); GpoStatus = "AllSettingsEnabled"; CreationTime = $Now.AddYears(-3); ModificationTime = $Now.AddMonths(-2); LinkedTo = "OU=Workstations,DC=contoso,DC=local"; LinkCount = 1 }
    [PSCustomObject]@{ Name = "Legacy Printer Deployment 2019"; Id = (New-Guid); GpoStatus = "AllSettingsDisabled"; CreationTime = $Now.AddYears(-7); ModificationTime = $Now.AddYears(-5); LinkedTo = ""; LinkCount = 0 }
)

# ---------------------------------------------------------------------------
# Security Baseline
# ---------------------------------------------------------------------------

Export-AssessmentCsv -Name "SecurityBaseline" -Data @(
    [PSCustomObject]@{ Check = "Minimum Password Length";                                Value = 8;   Severity = "Warning" }
    [PSCustomObject]@{ Check = "Password Complexity Enabled";                            Value = $true; Severity = "OK" }
    [PSCustomObject]@{ Check = "krbtgt Password Age (days)";                             Value = 227; Severity = "Warning" }
    [PSCustomObject]@{ Check = "Domain Admins Member Count";                             Value = 4;   Severity = "OK" }
    [PSCustomObject]@{ Check = "Non-Computer Accounts with Unconstrained Delegation";     Value = 1;   Severity = "Warning" }
    [PSCustomObject]@{ Check = "Enabled Accounts with Non-Expiring Passwords";            Value = 3;   Severity = "Warning" }
    [PSCustomObject]@{ Check = "Enabled Accounts Inactive 90+ Days";                      Value = 12;  Severity = "Warning" }
)

# ---------------------------------------------------------------------------
# DHCP
# ---------------------------------------------------------------------------

Export-AssessmentCsv -Name "DhcpScopes" -Data @(
    [PSCustomObject]@{ Server = "CONTOSO-DC01.contoso.local"; ScopeId = "10.10.2.0"; Name = "HQ-Workstations"; State = "Active"; StartRange = "10.10.2.50"; EndRange = "10.10.2.250"; PercentageInUse = 62.4; AddressesFree = 75;  AddressesInUse = 125 }
    [PSCustomObject]@{ Server = "CONTOSO-DC03.contoso.local"; ScopeId = "10.20.1.0"; Name = "DR-Workstations"; State = "Active"; StartRange = "10.20.1.50"; EndRange = "10.20.1.150"; PercentageInUse = 91.0; AddressesFree = 9;   AddressesInUse = 91  }
)

# ---------------------------------------------------------------------------
# Certificate Services
# ---------------------------------------------------------------------------

Export-AssessmentCsv -Name "CertificateServices" -Data @(
    [PSCustomObject]@{ CAName = "Contoso Issuing CA"; Server = "CONTOSO-DC02.contoso.local"; HasCertificate = $true; Reachable = "Yes" }
)

# ---------------------------------------------------------------------------
# File Services
# ---------------------------------------------------------------------------

Export-AssessmentCsv -Name "FileShares" -Data @(
    [PSCustomObject]@{ Server = "CONTOSO-DC01.contoso.local"; ShareName = "NETLOGON"; Path = "C:\Windows\SYSVOL\sysvol\contoso.local\SCRIPTS"; Description = "" }
    [PSCustomObject]@{ Server = "CONTOSO-DC01.contoso.local"; ShareName = "SYSVOL";   Path = "C:\Windows\SYSVOL\sysvol";                        Description = "" }
)

Export-AssessmentCsv -Name "DiskCapacity" -Data @(
    [PSCustomObject]@{ Server = "CONTOSO-DC01.contoso.local"; Drive = "C:"; SizeGB = 120; FreeSpaceGB = 54.2; FreePercent = 45.2 }
    [PSCustomObject]@{ Server = "CONTOSO-DC02.contoso.local"; Drive = "C:"; SizeGB = 120; FreeSpaceGB = 48.9; FreePercent = 40.8 }
    [PSCustomObject]@{ Server = "CONTOSO-DC04.contoso.local"; Drive = "C:"; SizeGB = 80;  FreeSpaceGB = 6.1;  FreePercent = 7.6  }
)

# ---------------------------------------------------------------------------
# DFS Namespace Health
# ---------------------------------------------------------------------------

Export-AssessmentCsv -Name "DfsNamespaceHealth" -Data @(
    [PSCustomObject]@{ Namespace = "\\contoso.local\Public"; Folder = "\\contoso.local\Public\HR";      TargetPath = "\\CONTOSO-FS01\HR$";      State = "Online" }
    [PSCustomObject]@{ Namespace = "\\contoso.local\Public"; Folder = "\\contoso.local\Public\Finance"; TargetPath = "\\CONTOSO-FS02\Finance$"; State = "Offline" }
)

# ---------------------------------------------------------------------------
# Event Log Analysis
# ---------------------------------------------------------------------------

Export-AssessmentCsv -Name "EventLogAnalysis" -Data @(
    [PSCustomObject]@{ Server = "CONTOSO-DC01.contoso.local"; LogName = "System";            ErrorCount = 2  }
    [PSCustomObject]@{ Server = "CONTOSO-DC01.contoso.local"; LogName = "Directory Service";  ErrorCount = 0  }
    [PSCustomObject]@{ Server = "CONTOSO-DC04.contoso.local"; LogName = "System";            ErrorCount = 34 }
)

# ---------------------------------------------------------------------------
# Windows Services
# ---------------------------------------------------------------------------

$CriticalServices = "NTDS", "DNS", "Netlogon", "Kdc", "W32Time", "DFSR"

Export-AssessmentCsv -Name "WindowsServices" -Data (
    ($DCs | Where-Object { $_.Online -eq "Yes" } | ForEach-Object {
        $DCName = $_.Name
        foreach ($Svc in $CriticalServices) {
            [PSCustomObject]@{
                Server      = $DCName
                ServiceName = $Svc
                Status      = "Running"
                StartType   = "Automatic"
                Healthy     = $true
            }
        }
    })
)

# ---------------------------------------------------------------------------
# Hybrid Identity
# ---------------------------------------------------------------------------

Export-AssessmentCsv -Name "EntraConnectScheduler" -Data ([PSCustomObject]@{
    SyncCycleEnabled       = $true
    SyncCycleInProgress    = $false
    NextSyncCycleStartTime = $Now.AddMinutes(18)
    LastSyncCycleStartTime = $Now.AddMinutes(-12)
})

Export-AssessmentCsv -Name "EntraConnectConnectorRuns" -Data @(
    [PSCustomObject]@{ ConnectorName = "contoso.local";      ConnectorType = "AD";       LastRunResult = "success"; LastRunDate = $Now.AddMinutes(-12) }
    [PSCustomObject]@{ ConnectorName = "contoso.onmicrosoft.com"; ConnectorType = "Azure AD"; LastRunResult = "success"; LastRunDate = $Now.AddMinutes(-11) }
)

Export-AssessmentCsv -Name "PtaAgentStatus" -Data @(
    [PSCustomObject]@{ Server = "CONTOSO-PTA01.contoso.local"; Status = "Running"; Healthy = $true }
    [PSCustomObject]@{ Server = "CONTOSO-PTA02.contoso.local"; Status = "Stopped"; Healthy = $false }
)

Export-AssessmentCsv -Name "CloudSyncStatus" -Data @(
    [PSCustomObject]@{ Server = "CONTOSO-SYNC01.contoso.local"; Status = "Running"; Healthy = $true }
)

Export-AssessmentCsv -Name "EntraIdAssessment" -Data ([PSCustomObject]@{
    TenantName       = "Contoso Manufacturing"
    TenantId         = "9f3a2b1c-1234-4a5b-9c6d-abcdef123456"
    TotalUsers       = 842
    SyncedUsers      = 790
    CloudOnlyUsers   = 52
    GlobalAdminCount = 6
})

Export-AssessmentCsv -Name "ConditionalAccessPolicies" -Data @(
    [PSCustomObject]@{ Name = "Require MFA for Admins";        State = "enabled";                            CreatedDate = $Now.AddYears(-2); ModifiedDate = $Now.AddMonths(-3) }
    [PSCustomObject]@{ Name = "Block Legacy Authentication";   State = "enabled";                            CreatedDate = $Now.AddYears(-2); ModifiedDate = $Now.AddMonths(-6) }
    [PSCustomObject]@{ Name = "Require MFA for All Users";     State = "enabledForReportingButNotEnforced";  CreatedDate = $Now.AddMonths(-1); ModifiedDate = $Now.AddMonths(-1) }
)

Write-Host ""
Write-Success "Demo data generated for Contoso Manufacturing (fictitious)."
Write-Host "Run .\scripts\New-AssessmentDashboard.ps1 next to build the HTML dashboard."
