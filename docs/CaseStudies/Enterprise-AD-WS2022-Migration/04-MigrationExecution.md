# 04 - Migration Execution

Execution runbook and log for the plan defined in
[03 - Migration Plan](03-MigrationPlan.md). Update the log table as each step
is completed - do not mark a phase's status as Done until
[05 - Post-Migration Validation](05-PostMigrationValidation.md) has passed
for that phase.

## Pre-Migration Remediation Checklist

| Item | Status | Date | Notes |
|---|---|---|---|
| Restore connectivity/replication on DCBR23 | In Progress | 2026-07-29 | Network team investigating firewall path Branch-North-02 -> Hub-Central. |
| Complete FRS -> DFSR migration on branches.fabrikam.com | Not Started | | Blocked on DCBR23 fix (do not run `dfsrmig /setglobalstate 3` while replication is unhealthy). |
| Disable SMBv1 on DCBR22 | Done | 2026-07-28 | Verified via `Get-SmbServerConfiguration`. |
| Fix Kerberos pre-auth on `svc-legacy-backup` | Done | 2026-07-28 | Migrated to a gMSA; old account disabled. |
| Free up disk space on DCTRE20 | In Progress | 2026-07-29 | Clearing old WinSxS/log files; extending volume if still under 20% after cleanup. |
| Deploy LAPS forest-wide | Not Started | | Scheduled to start once Phase 1 pilot is validated. |

## Phase 1 - Pilot (fabrikam.com)

**Status: Not Started - blocked on Pre-Migration Remediation.**

| Step | Status | Date | Owner | Notes |
|---|---|---|---|---|
| Stage 2x Windows Server 2022 servers at HQ-Fabrikam / DR-Fabrikam | Not Started | | Infra team | |
| Run `adprep /forestprep` | Not Started | | AD team | Requires Schema Admins + Enterprise Admins. |
| Run `adprep /domainprep /gpprep` (fabrikam.com) | Not Started | | AD team | |
| Promote new DCs as additional DCs | Not Started | | AD team | |
| Verify replication + DNS registration | Not Started | | AD team | |
| Transfer Schema Master, Domain Naming Master | Not Started | | AD team | |
| Transfer fabrikam.com PDC/RID/Infrastructure Master | Not Started | | AD team | |
| 48-hour soak period | Not Started | | AD team | |
| Run full toolkit assessment; compare Infrastructure Score | Not Started | | AD team | Must not regress below 76/100 baseline. |
| Demote DCFAB20, DCFAB21 | Not Started | | AD team | |
| Go/no-go checkpoint for Phase 2 | Not Started | | Project lead | |

## Phase 2-5

Not started. Will be populated using the same table format once Phase 1 has
passed its go/no-go checkpoint - see the phase scope and order defined in
[03 - Migration Plan &sect;3](03-MigrationPlan.md#3-rollout-order).

## Execution Log

Chronological log of significant actions, independent of phase/step tables
above - useful for audits and post-incident review.

| Date | Action | Owner | Result |
|---|---|---|---|
| 2026-07-27 | Ran full toolkit assessment (Discovery + Health) - established baseline | AD team | Infrastructure Score 76/100; 11 findings logged - see [02 - Health Assessment](02-HealthAssessment.md). |
| 2026-07-28 | Disabled SMBv1 on DCBR22 | AD team | Confirmed via re-run of `Get-HLSecurityBaseline`. |
| 2026-07-28 | Replaced `svc-legacy-backup` with a gMSA | Security team | Old account disabled, not yet deleted (30-day retention before removal). |
| 2026-07-29 | Opened network ticket for DCBR23 replication failure | Network team | Root cause suspected: firewall rule change at Branch-North-02 during a recent circuit migration. |
| 2026-07-29 | Started disk cleanup on DCTRE20 | AD team | In progress. |

Next: [05 - Post-Migration Validation](05-PostMigrationValidation.md).
