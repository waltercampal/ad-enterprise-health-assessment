# 05 - Post-Migration Validation

Validation checklist to run after **every** phase in
[03 - Migration Plan](03-MigrationPlan.md), before demoting the outgoing
Windows Server 2016 Domain Controller(s) and before moving to the next
phase. As of this writing the migration is still in the pre-migration
remediation stage (see [04 - Migration Execution](04-MigrationExecution.md)),
so this document is the checklist/template that will be filled in with real
results as each phase completes.

## Validation Checklist (per phase)

Run [`Start-EnterpriseAssessment.ps1`](../../../Start-EnterpriseAssessment.ps1)
in full and confirm:

- [ ] **Replication** - `Get-HLReplicationHealth` reports `Healthy` for every
      partner involving the new Domain Controller(s), in both directions.
- [ ] **DNS** - new DC(s) show `Healthy` for DNS Service, hostname
      resolution, and LDAP/Kerberos SRV records; old SRV/A records for
      demoted DCs are gone from DNS within one scavenging cycle.
- [ ] **Time** - new DC(s) report a `Healthy` time source consistent with the
      domain hierarchy (PDC Emulator -> external NTP).
- [ ] **SYSVOL** - new DC(s) show `Healthy` SYSVOL share accessibility; GPO
      SYSVOL/AD version consistency holds for every GPO in the domain.
- [ ] **FSMO** - `Get-FSMORoles` output matches the intended post-phase
      role holders (see [03 - Migration Plan &sect;4](03-MigrationPlan.md#4-fsmo-role-transfer-order)).
- [ ] **Security Baseline** - no regressions (SMBv1 still disabled, no new
      privileged accounts with Kerberos pre-auth disabled or passwords set
      to never expire).
- [ ] **Server Configuration** - new DC(s) show `Windows Server 2022` and
      healthy disk space.
- [ ] **Event Log** - no new Critical/Error events in Directory Service, DNS
      Server or DFS Replication logs on the new DC(s) during the soak
      period.
- [ ] **Infrastructure Score** - equal to or higher than the pre-phase
      baseline (82/100 at the start of this migration - see
      [02 - Health Assessment](02-HealthAssessment.md)).
- [ ] **Application/dependency check** - anything identified in
      [Migration Readiness](02-HealthAssessment.md) as co-located (ADCS,
      DHCP, NPS) on a DC being demoted this phase has been confirmed moved
      or explicitly out of scope for this phase.

## Decommission Checklist (before demoting an outgoing 2016 DC)

Only proceed once **all** items above pass for the phase:

- [ ] 48-hour minimum soak period completed with no new Critical findings.
- [ ] `repadmin /showrepl` clean on the outgoing DC immediately before
      demotion.
- [ ] No remaining FSMO roles held by the outgoing DC.
- [ ] No client/application configuration still hard-coded to the outgoing
      DC's hostname or IP (LDAP binds, RADIUS/NPS clients, legacy scripts).
- [ ] Demote (`Uninstall-ADDSDomainController`), then confirm:
  - [ ] Server object removed from `CN=Servers,CN=<Site>,CN=Sites,CN=Configuration`.
  - [ ] DNS A/SRV records for the demoted DC removed.
  - [ ] No lingering objects (`repadmin /removelingeringobjects` if the DC
        was offline longer than the tombstone lifetime).

## Migration Closure Criteria

The migration is considered complete when:

- [ ] All 12 Domain Controllers are Windows Server 2022 (0 remaining 2016 DCs
      per [`reports/samples/DomainControllerInventory.csv`](../../../reports/samples/DomainControllerInventory.csv)
      schema).
- [ ] All FSMO roles are held by Windows Server 2022 Domain Controllers.
- [ ] `Get-HLMigrationReadiness` reports `Healthy` across the board (schema
      version, no legacy OS DCs, FRS/DFSR complete, roles inventoried).
- [ ] Infrastructure Score has improved from the 82/100 baseline (target:
      95+, since several of the original findings - SMBv1, Kerberos pre-auth,
      disk space - are remediated as part of this migration, not just
      carried forward).
- [ ] This case study's execution log ([04](04-MigrationExecution.md)) and
      checklists above are fully checked off and archived.
