# Case Study: Enterprise AD Windows Server 2016 -> 2022 Migration

A real enterprise Active Directory migration, documented end-to-end using
this toolkit. The client's real hostnames, IP ranges, domain names and
branch/site names have been replaced with a fictional environment
(`fabrikam.com`) since this repository is public - see the note in
[01 - Discovery](01-Discovery.md) for details. The findings, remediation
items and migration approach are representative of the real engagement.

## Contents

1. [Discovery](01-Discovery.md) - forest/domain/DC inventory and initial
   replication check.
2. [Health Assessment](02-HealthAssessment.md) - full results across every
   Health module (DNS, Time, SYSVOL, Group Policy, Security, Server
   Configuration, Event Log, Migration Readiness) and the Infrastructure
   Score.
3. [Migration Plan](03-MigrationPlan.md) - remediation prerequisites,
   rollout order, FSMO transfer sequence, maintenance windows and timeline.
4. [Migration Execution](04-MigrationExecution.md) - runbook checklists and
   the chronological execution log.
5. [Post-Migration Validation](05-PostMigrationValidation.md) - the
   per-phase validation checklist, decommission checklist, and migration
   closure criteria.

See also [Assessment Methodology](../Assessment-Methodology.md) for how the
toolkit itself works, and [`reports/samples/`](../../../reports/samples/) for
the underlying (anonymized) machine-readable results.
