# Assessment Methodology

This document describes how the Enterprise Active Directory Health
Assessment Toolkit evaluates an environment, and how to read its results.

## 1. Assessment Phases

The toolkit runs in three phases, orchestrated by
[`Start-EnterpriseAssessment.ps1`](../Start-EnterpriseAssessment.ps1):

1. **Discovery** (`scripts/*.ps1`) - inventories the environment: forest,
   domains, FSMO role holders, Domain Controllers and AD Sites. Discovery
   scripts return plain `[PSCustomObject]` data and do not judge health.
2. **Health Assessment** (`scripts/Health/*.ps1`) - runs a set of independent
   checks against the discovered Domain Controllers/domains and returns
   standardized `ADEHAT.HealthResult` objects (see below).
3. **Reporting** (`scripts/Reporting/*.ps1`) - aggregates the Health results
   into an Infrastructure Score, an HTML report, and a plain-text executive
   summary.

Every phase exports its raw output to `reports/*.csv` (git-ignored - see
[`reports/README.md`](../reports/README.md)) so results can be reviewed,
diffed between runs, or fed into other tooling (Excel, Power BI, etc.).

## 2. The HealthResult Model

Every Health module returns one or more objects created with
`New-HealthResult` (defined in
[`scripts/Common/Common.ps1`](../scripts/Common/Common.ps1)):

| Field | Meaning |
|-------|---------|
| `Category` | Functional area (Replication, DNS, Time, SYSVOL, GroupPolicy, Security, ServerConfig, EventLog, MigrationReadiness). |
| `Check` | The specific thing being verified (e.g. "DNS Service", "Replication Partner"). |
| `Target` | The object evaluated - usually a Domain Controller hostname, a domain name, or an account. |
| `Status` | `Healthy`, `Warning`, `Critical`, or `Skipped`. |
| `Severity` | `Info`, `Low`, `Medium`, or `High` - how much this finding matters if left unresolved. |
| `Message` | What was found. |
| `Recommendation` | The corrective action, when `Status` is not `Healthy`. |

This is the single contract every Health module must follow. Reporting
scripts (`Get-ExecutiveSummary.ps1`, `Get-HTMLReport.ps1`,
`Get-InfrastructureScore.ps1`) only understand this shape - they never
inspect module-specific fields. This is what lets new Health checks be added
without touching the reporting layer.

`Status = Skipped` is used when a check could not run for an operational
reason unrelated to health (a DC intentionally offline for maintenance, a
module not installed) - it is excluded from the Infrastructure Score instead
of counting against it.

## 3. Health Categories

| Category | Module | What it checks |
|----------|--------|-----------------|
| Replication | `Get-HLReplicationHealth.ps1` | Inbound replication status per partner via `Get-ADReplicationPartnerMetadata`. |
| DNS | `Get-HLDNSHealth.ps1` | DNS Server service, hostname resolution, LDAP/Kerberos SRV records. |
| Time | `Get-HLTimeHealth.ps1` | W32Time service and configured time source. |
| SYSVOL | `Get-HLSysvolHealth.ps1` | FRS-to-DFSR migration state per domain and SYSVOL share reachability per DC. |
| GroupPolicy | `Get-HLGPOHealth.ps1` | SYSVOL/AD version consistency per GPO and orphaned (unlinked) GPOs. |
| Security | `Get-HLSecurityBaseline.ps1` | SMBv1 exposure, LAPS deployment, privileged account hygiene (password never expires, Kerberos pre-auth). |
| ServerConfig | `Get-HLServerConfig.ps1` | Operating system version and system drive free space. |
| EventLog | `Get-HLEventLogHealth.ps1` | Recent Critical/Error/Warning events in Directory Service, DNS Server and DFS Replication logs. |
| MigrationReadiness | `Get-HLMigrationReadiness.ps1` | Schema version, legacy (2008/2008 R2) DC blockers, functional levels, and co-located server roles (ADCS/DHCP/NPS) - see [Migration Readiness](#5-migration-readiness-checks-2016---2022) below. |

## 4. Infrastructure Score

`Get-InfrastructureScore.ps1` computes a single 0-100 score:

- Each non-`Skipped` result contributes a weight based on its `Severity`
  (Info/Low = 1, Medium = 2, High = 3).
- `Healthy` results earn the full weight, `Warning` earns half, `Critical`
  earns none.
- `Score = 100 * (earned points / possible points)`.

This means one `Critical`/`High` finding (e.g. a failed replication link)
moves the score more than several `Info`-level observations - the score is
meant to communicate risk, not just a pass/fail tally.

## 5. Migration Readiness Checks (2016 -> 2022)

Beyond generic health, `Get-HLMigrationReadiness.ps1` targets what
specifically blocks or complicates introducing Windows Server 2022 Domain
Controllers into an existing Windows Server 2016 environment:

- **Schema version** - Windows Server 2022 requires `adprep /forestprep` /
  `/domainprep` to raise the schema; the check flags forests still below the
  required `objectVersion`.
- **Legacy OS blockers** - Windows Server 2022 cannot be promoted into a
  domain that still has Windows Server 2008/2008 R2 Domain Controllers. This
  is a hard blocker, not a recommendation.
- **FRS -> DFSR migration** - Windows Server 2022 does not support the File
  Replication Service. Any domain still using FRS for SYSVOL (migration
  state other than `Eliminated`) must complete the DFSR migration first.
- **Co-located server roles** - ADCS, DHCP and NPS/RADIUS installed directly
  on a Domain Controller need a dedicated migration plan before that DC can
  be decommissioned; the check flags which DCs need one.
- **RODC readiness** - Read-Only Domain Controllers are called out
  separately since branch-office replacement usually requires confirming the
  replica-source DC and Password Replication Policy.

See the [Enterprise AD WS2022 Migration case study](CaseStudies/Enterprise-AD-WS2022-Migration/)
for these checks applied end-to-end, from discovery through post-migration
validation.

## 6. Extending the Toolkit

To add a new Health check:

1. Create `scripts/Health/Get-HL<Name>Health.ps1` as a function
   `Get-HL<Name>Health` accepting at least `-DomainControllers` (and
   `-Domains`/`-Forest` if the check is domain- or forest-scoped).
2. Return an array of `New-HealthResult` objects - one per finding.
3. Wire it into [`Start-EnterpriseAssessment.ps1`](../Start-EnterpriseAssessment.ps1):
   call the function, add its output to `$HealthResults`, and export it with
   `Export-AssessmentCsv`.

No changes to the Reporting scripts are needed - they consume
`$HealthResults` generically.
