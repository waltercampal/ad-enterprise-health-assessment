# Roadmap

## Version 1.0 - Foundation

- [x] Domain Controller Inventory
- [x] Forest Information
- [x] Domain Information
- [x] FSMO Roles
- [x] Site Topology
- [x] Replication Status
- [x] SYSVOL Health
- [x] DNS Assessment
- [x] Group Policy Inventory
- [x] Security Baseline
- [x] HTML Report
- [x] CSV Export

---

## Version 1.1 - Infrastructure

- [ ] DHCP Assessment
- [ ] Certificate Services (detected as a co-located DC role by Migration Readiness; not yet its own assessment module)
- [ ] File Services
- [x] DFS Health (SYSVOL - see `Get-HLSysvolHealth.ps1`)
- [x] Event Log Analysis (`Get-HLEventLogHealth.ps1`)
- [ ] Windows Services (beyond DNS/W32Time/Netlogon already covered per-check)

---

## Version 1.5 - Windows Server 2016 -> 2022 Migration Readiness

- [x] Schema version / adprep readiness check
- [x] Legacy OS (2008/2008 R2) blocker detection
- [x] FRS -> DFSR migration state check
- [x] Co-located server role detection (ADCS/DHCP/NPS)
- [x] End-to-end migration case study (Discovery -> Post-Migration Validation)

See `Get-HLMigrationReadiness.ps1` and
[`docs/CaseStudies/Enterprise-AD-WS2022-Migration/`](docs/CaseStudies/Enterprise-AD-WS2022-Migration/).

---

## Version 2.0 - Hybrid Identity

- [ ] Entra Connect
- [ ] Entra ID Assessment
- [ ] Hybrid Identity
- [ ] PTA Agents
- [ ] Cloud Sync
- [ ] Conditional Access Review

---

## Version 3.0 - Reporting

- [ ] Executive Dashboard
- [x] Infrastructure Score
- [x] HTML Portal
- [ ] Interactive Reports

---

## Future Ideas

- Azure Assessment
- SQL Assessment
- VMware Assessment
- Power BI Dashboard
- Automatic Documentation
