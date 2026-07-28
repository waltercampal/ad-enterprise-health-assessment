# Toolkit Completion Plan - Windows Server 2016 -> 2022 Migration Readiness

This document records the plan used to take the toolkit from its initial
partial state to a complete, working assessment process capable of
supporting a real Windows Server 2016 -> 2022 Active Directory migration,
and tracks what has been completed.

## Phase 0 - Stabilize the toolkit

- [x] Fix `Get-HLDNSHealth.ps1` / `Get-HLTimeHealth.ps1` to use the
      standardized `New-HealthResult` contract (`Healthy/Warning/Critical/Skipped`,
      `-Message`) instead of the non-existent `Pass/Fail`/`-Details`.
- [x] Refactor `Get-HLReplicationHealth.ps1` into the same
      `Get-HL<Name>Health -DomainControllers ...` function pattern as every
      other Health module, and wire all Health modules into
      `Start-EnterpriseAssessment.ps1`.
- [x] Remove the duplicate CSV export helper (`Export-Report.ps1`) and the
      double-export in `Get-FSMORoles.ps1` / `Get-SitesInformation.ps1`.
- [x] Remove `temp.ps1` scratch file from the case study folder.

## Phase 1 - Complete the core Health checks

- [x] `Get-HLSysvolHealth.ps1` - FRS/DFSR migration state and SYSVOL share
      accessibility.
- [x] `Get-HLGPOHealth.ps1` - SYSVOL/AD version consistency, orphaned GPOs.
- [x] `Get-HLSecurityBaseline.ps1` - SMBv1, LAPS deployment, privileged
      account hygiene.
- [x] `Get-HLServerConfig.ps1` - OS version, disk space.
- [x] `Get-HLEventLogHealth.ps1` - Directory Service / DNS Server / DFS
      Replication log errors.

## Phase 2 - Migration-specific checks (2016 -> 2022)

- [x] `Get-HLMigrationReadiness.ps1` - schema version, legacy OS (2008/2008 R2)
      blockers, functional levels, co-located server roles (ADCS/DHCP/NPS),
      RODC readiness notes.

## Phase 3 - Reporting

- [x] `Get-InfrastructureScore.ps1` - single 0-100 score, severity-weighted.
- [x] `Get-HTMLReport.ps1` - self-contained HTML report (light/dark aware).
- [x] `Get-ExecutiveSummary.ps1` extended to cover every Health category and
      the Migration Readiness section.

## Phase 4 - Documentation

- [x] [`docs/Assessment-Methodology.md`](Assessment-Methodology.md) - the
      HealthResult contract, category reference, scoring model, and how to
      extend the toolkit.
- [x] Case study completed end-to-end:
      [Discovery](CaseStudies/Enterprise-AD-WS2022-Migration/01-Discovery.md),
      [Health Assessment](CaseStudies/Enterprise-AD-WS2022-Migration/02-HealthAssessment.md),
      [Migration Plan](CaseStudies/Enterprise-AD-WS2022-Migration/03-MigrationPlan.md),
      [Migration Execution](CaseStudies/Enterprise-AD-WS2022-Migration/04-MigrationExecution.md),
      [Post-Migration Validation](CaseStudies/Enterprise-AD-WS2022-Migration/05-PostMigrationValidation.md).
- [x] `reports/samples/` populated with a full, internally-consistent
      fictional sample dataset (`fabrikam.com`) matching every report the
      toolkit produces.

## Data handling (important - read before running against a real environment)

The client environment behind this case study is a real bank. This
repository is public, so:

- Real hostnames/IPs/site names/security findings must **never** be
  committed. `Start-EnterpriseAssessment.ps1` writes real output to
  `reports/*.csv|txt|html`, which is excluded via `.gitignore`.
- Only `reports/samples/` (fictional `fabrikam.com` data) is tracked in git
  and safe to show publicly / link from a CV or portfolio.
- **The git history for this branch already contains the original,
  un-anonymized data** (real hostnames, IPs and ~400 real branch site names)
  from before this cleanup. Sanitizing the current working tree does not
  remove it from history. If this branch/repo is public, treat that data as
  already exposed until the history is rewritten (e.g. `git filter-repo`)
  and force-pushed - a separate, deliberate action that was not taken as
  part of this cleanup because it rewrites shared history and needs explicit
  sign-off.

## Status

All phases above are complete. Remaining work is executing the actual
migration against the real environment, tracked in the case study's
[Migration Execution log](CaseStudies/Enterprise-AD-WS2022-Migration/04-MigrationExecution.md),
not in this file.
