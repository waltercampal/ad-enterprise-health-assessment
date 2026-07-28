# 03 - Migration Plan

Strategy: **clean-install new Windows Server 2022 Domain Controllers, migrate
FSMO roles, then demote and decommission the Windows Server 2016 Domain
Controllers.** No in-place OS upgrades - in-place upgrades of Domain
Controllers are explicitly discouraged by Microsoft for production
environments and would not resolve the SMBv1/disk-space/CA co-location
findings already on record.

## 1. Pre-Migration Remediation (blocking)

Must close before Phase 1 begins - these come directly from
[02 - Health Assessment](02-HealthAssessment.md):

| Item | Owner | Exit criteria |
|---|---|---|
| Restore connectivity/replication on DCBR23 (Branch-North-02) | Network + AD team | `repadmin /replsummary` shows 0 errors; DNS/SYSVOL checks pass |
| Complete FRS -> DFSR migration on branches.fabrikam.com | AD team | `dfsrmig /getglobalstate` returns `Eliminated` |
| Disable SMBv1 on DCBR22 | AD team | `Get-SmbServerConfiguration` shows `EnableSMB1Protocol = False` |
| Fix Kerberos pre-auth on `svc-legacy-backup` | Security team | Account requires pre-auth, or is replaced with a gMSA |
| Free up disk space on DCTRE20 (currently 6%) | AD team | > 20% free on system drive |
| Deploy LAPS forest-wide | Security team | `ms-Mcs-AdmPwd` schema attribute present and GPO deployed |

## 2. Migration Prerequisites

1. Run `adprep /forestprep` (Enterprise Admins + Schema Admins) from Windows
   Server 2022 media on the Schema Master (DCFAB20).
2. Run `adprep /domainprep /gpprep` on each domain's Infrastructure Master.
3. Confirm forest/domain functional levels remain at Windows Server 2016 or
   higher (already true - see [01 - Discovery](01-Discovery.md)).
4. Plan the Enterprise CA co-located on DCTRE20 separately, following
   Microsoft's CA role migration guidance - it is **not** part of the DC
   promotion/demotion sequence below and must not block it.

## 3. Rollout Order

Rationale: pilot at HQ where support is immediate, prove the process, then
roll out to lines of business, and do the branch network (highest count,
lowest local support) last and in batches.

| Phase | Scope | New 2022 DCs | Notes |
|---|---|---|---|
| Phase 1 - Pilot | fabrikam.com (root) | 2 (replacing DCFAB20, DCFAB21) | Includes Schema Master + Domain Naming Master transfer. Go/no-go checkpoint before Phase 2. |
| Phase 2 | retail.fabrikam.com | 3 | |
| Phase 3 | treasury.fabrikam.com | 2 | Coordinate with the CA migration; do not demote DCTRE20 until the CA role has moved. |
| Phase 4 | branches.fabrikam.com - Hub-Central | 2 (replacing DCBR20, DCBR21) | Requires Phase 1 remediation items closed first. |
| Phase 5 | branches.fabrikam.com - Branch sites | 3 (replacing DCBR22, DCBR23, DCBR24) | Batch by site; DCBR24 is an RODC - confirm replica-source and Password Replication Policy per [Migration Readiness](../Assessment-Methodology.md#5-migration-readiness-checks-2016---2022) before staging its replacement. |

For each phase:

1. Stage new Windows Server 2022 server(s) in the target site.
2. `dcpromo`/`Install-ADDSDomainController` to add as additional DC (do not
   transfer FSMO yet).
3. Verify replication both directions (`repadmin /replsummary`,
   `repadmin /showrepl`) and DNS registration.
4. Re-point DHCP scope options / site-affinity as needed so clients start
   using the new DC.
5. Transfer any FSMO roles held by the outgoing DC(s) in this phase (see
   role-transfer order below).
6. Demote the outgoing Windows Server 2016 DC(s)
   (`Uninstall-ADDSDomainController`).
7. Confirm metadata cleanup (`repadmin /removelingeringobjects` if needed,
   stale DNS records removed).
8. Run the full toolkit assessment again; confirm Infrastructure Score has
   not regressed before moving to the next phase.

## 4. FSMO Role Transfer Order

Transfer roles onto an already-promoted 2022 DC in the same phase that
retires their current holder:

1. Schema Master, Domain Naming Master (DCFAB20 -> new HQ DC) - Phase 1.
2. fabrikam.com PDC Emulator, RID Master, Infrastructure Master (DCFAB21/DCFAB20 -> new HQ DCs) - Phase 1.
3. retail.fabrikam.com roles (DCRET20/21/22 -> new retail DCs) - Phase 2.
4. treasury.fabrikam.com roles (DCTRE20/21 -> new treasury DCs) - Phase 3, after CA role has moved off DCTRE20.
5. branches.fabrikam.com roles (DCBR20/21/22 -> new branch DCs) - Phase 4.

## 5. Maintenance Windows & Rollback

- All promotions/demotions during off-peak hours per site (banking branch
  network - avoid business hours and end-of-day settlement windows).
- Each phase keeps at least one Windows Server 2016 DC online as a fallback
  until the new DC(s) have replicated cleanly and been validated (see
  [05 - Post-Migration Validation](05-PostMigrationValidation.md)) for a
  minimum 48-hour soak period before demotion.
- Rollback path per phase: if the new DC fails validation, do not transfer
  FSMO roles and do not demote the outgoing DC; remove the new DC from AD
  DS and investigate.

## 6. Timeline (indicative)

| Phase | Duration |
|---|---|
| Pre-migration remediation | 2 weeks |
| Phase 1 - Pilot | 1 week + 1 week soak |
| Phase 2 | 1 week |
| Phase 3 (incl. CA coordination) | 2 weeks |
| Phase 4 | 1 week |
| Phase 5 (branch batches) | 3-4 weeks |

Next: [04 - Migration Execution](04-MigrationExecution.md).
