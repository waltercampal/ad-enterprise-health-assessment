# Assessment Methodology

This toolkit assesses an Active Directory environment in three phases, mirroring how the risk and blast radius of issues typically grow: from the directory itself, to the infrastructure around it, to the hybrid identity layer that depends on it.

## Forest-wide scope

Every module assesses the **whole forest** — the root domain and every child/tree domain — not just the domain the machine running the assessment happens to be joined to. `Common.ps1` provides two helpers used throughout: `Get-ForestDomains` (every domain's DNS name, via `Get-ADForest`) and `Get-ForestDomainControllers` (every Domain Controller in every domain, by querying `Get-ADDomainController -Filter * -Server <domain>` per domain instead of relying on the caller's default domain context). Domain-scoped modules (Domain Information, FSMO Roles, GPO Inventory, Security Baseline) loop over `Get-ForestDomains` and tag each row with the `Domain` it came from; DC-scoped modules (Replication, SYSVOL, DNS, Windows Services, Event Logs, File Services) loop over `Get-ForestDomainControllers`. Forest-wide data that already lives in the Configuration partition (Sites, Site Links, Certificate Services, DHCP) needed no change — it was already forest-scoped.

## Phase 1 — Foundation (`Start-EnterpriseAssessment.ps1`)

Establishes the baseline: what the forest and domain look like, who holds the FSMO roles, whether Domain Controllers are healthy and replicating, whether SYSVOL and DNS are consistent, and whether Group Policy and core security controls meet a reasonable baseline.

| Module | What it checks |
|---|---|
| `Get-ForestInformation.ps1` | Forest mode, domains, sites, global catalogs, UPN suffixes |
| `Get-DomainInformation.ps1` | Domain mode, NetBIOS name, FSMO holders for the domain |
| `Get-FSMORoles.ps1` | All 5 FSMO role holders (forest + domain) |
| `Get-DomainControllerInventory.ps1` | Every DC's site, IP, OS, GC/RODC status, and reachability |
| `Get-SiteTopology.ps1` | Sites, subnets, site links, cost and replication interval |
| `Get-ReplicationStatus.ps1` | Inbound replication partner metadata and failure counts |
| `Get-SysvolHealth.ps1` | DFSR replication state for the SYSVOL replicated folder |
| `Get-DnsAssessment.ps1` | Zones, forwarders, scavenging configuration per DC |
| `Get-GPOInventory.ps1` | Every GPO, its status, and whether it is actually linked |
| `Get-SecurityBaseline.ps1` | Password policy, krbtgt age, Domain Admins size, delegation, stale/never-expiring accounts |

## Phase 2 — Infrastructure (`Start-InfrastructureAssessment.ps1`)

Looks at the services that ride on top of AD and that a DC health check alone would miss: DHCP scope exhaustion, certificate services reachability, file share/disk capacity, DFS namespace availability, noisy event logs, and whether the core AD-related Windows services are actually running.

| Module | What it checks |
|---|---|
| `Get-DhcpAssessment.ps1` | Authorized DHCP servers, scope utilization |
| `Get-CertificateServicesAssessment.ps1` | Registered Enrollment Services (CAs) and reachability |
| `Get-FileServicesAssessment.ps1` | SMB shares and logical disk free space per DC |
| `Get-DfsHealth.ps1` | DFS namespace folder targets and their online/offline state |
| `Get-EventLogAnalysis.ps1` | Error/Critical event counts (last 24h) across System, Application, Directory Service logs |
| `Get-WindowsServicesAssessment.ps1` | NTDS, DNS, Netlogon, KDC, W32Time, DFSR service health per DC |

## Phase 3 — Hybrid Identity (`Start-HybridIdentityAssessment.ps1`)

Extends the assessment into Microsoft Entra ID for organizations running hybrid identity — sync health, authentication agent redundancy, and Conditional Access posture. This phase is interactive (Microsoft Graph sign-in) and is run separately from the unattended on-prem phases.

| Module | What it checks |
|---|---|
| `Get-EntraConnectStatus.ps1` | Sync scheduler state and last connector run result (run on the sync server) |
| `Get-PtaAgentStatus.ps1` | Pass-through Authentication agent service health |
| `Get-CloudSyncStatus.ps1` | Cloud Sync provisioning agent service health |
| `Get-EntraIdAssessment.ps1` | Tenant user counts (synced vs. cloud-only), Global Administrator count |
| `Get-ConditionalAccessReview.ps1` | Conditional Access policies and their enforcement state |

## Reporting

Every module exports its findings to `reports\<ModuleName>.csv`. `New-AssessmentDashboard.ps1` reads whichever CSVs exist and produces `reports\AssessmentDashboard.html`: a single self-contained file with an overall Infrastructure Health Score, a traffic-light status per area, and collapsible detail tables — no server or internet connection required to view it.

## Scoring

Each area's score is the fraction of underlying checks that passed (e.g. DCs online, replication links without failures, security baseline items marked OK). The overall score is the total passed checks divided by the total checks across every area that produced data. Areas with no data (a module wasn't run, or doesn't apply to the environment) are shown as informational and excluded from the score rather than counted as failures.

| Score | Grade |
|---|---|
| 90–100 | Excellent |
| 75–89 | Good |
| 60–74 | Needs Attention |
| 0–59 | Critical |

## Demo / Portfolio Use

`New-DemoData.ps1` populates `reports\` with fictitious data for a fake company ("Contoso Manufacturing"), matching the exact schema every real module produces, including a handful of intentionally seeded findings so the resulting dashboard looks like a real assessment rather than an unrealistic all-green environment. This is what powers the public, sanitized version of this toolkit — see `examples/sample-report/`.
