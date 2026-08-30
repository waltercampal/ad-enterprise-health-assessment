# Enterprise Active Directory Health Assessment Toolkit

Enterprise-grade PowerShell toolkit for assessing the health, security, and operational readiness of Microsoft Active Directory environments.

---

## Overview

Large Active Directory environments become increasingly complex over time.

Replication issues, DNS inconsistencies, outdated Domain Controllers, legacy configurations, and insufficient documentation can reduce security, impact performance, and increase operational risk.

This toolkit provides a structured assessment methodology to evaluate the overall health of an Active Directory infrastructure and generate actionable recommendations — including an executive HTML dashboard with an overall Infrastructure Health Score.

> **Trying it out without a real AD environment?** Run `.\scripts\New-DemoData.ps1` to populate `reports\` with fictitious data, then `.\scripts\New-AssessmentDashboard.ps1` to build the dashboard. A pre-generated sample lives in [`examples/sample-report/`](examples/sample-report/) — open `AssessmentDashboard.html` directly in a browser.

---

## Getting Started

Run from an elevated PowerShell session with the RSAT Active Directory module installed (and DNS Server / GroupPolicy / DHCP Server RSAT tools for the modules that use them):

```powershell
# Phase 1 — Foundation: forest, domain, FSMO, DCs, sites, replication, SYSVOL, DNS, GPOs, security baseline
.\Start-EnterpriseAssessment.ps1

# Phase 2 — Infrastructure: DHCP, Certificate Services, File Services, DFS, Event Logs, Windows Services
.\Start-InfrastructureAssessment.ps1

# Phase 3 — Hybrid Identity: Entra Connect, PTA, Cloud Sync, Entra ID, Conditional Access
# (interactive — prompts for Microsoft Graph sign-in)
.\Start-HybridIdentityAssessment.ps1

# Build the executive dashboard from whichever reports\*.csv files exist
.\scripts\New-AssessmentDashboard.ps1
```

Each module can also be run individually from `scripts\`. Every module degrades gracefully — if a required PowerShell module (e.g. `DhcpServer`, `Microsoft.Graph`) isn't installed, it prints a warning and skips instead of failing the whole run.

---

## Assessment Areas

| Area | Status |
|---|---|
| Forest & Domain Information | ✅ |
| FSMO Roles | ✅ |
| Domain Controller Inventory | ✅ |
| Site Topology | ✅ |
| Active Directory Replication | ✅ |
| SYSVOL / DFSR Health | ✅ |
| DNS Configuration | ✅ |
| Group Policy Inventory | ✅ |
| Security Baseline | ✅ |
| DHCP | ✅ |
| Certificate Services (AD CS) | ✅ |
| File Services & Disk Capacity | ✅ |
| DFS Namespace Health | ✅ |
| Event Log Analysis | ✅ |
| Windows Services | ✅ |
| Microsoft Entra Connect Sync | ✅ |
| PTA / Cloud Sync Agents | ✅ |
| Microsoft Entra ID Tenant Assessment | ✅ |
| Conditional Access Review | ✅ |
| Executive HTML Dashboard & Infrastructure Score | ✅ |

---

## Deliverables

- Executive HTML Dashboard with an overall Infrastructure Health Score
- Technical Assessment Report (CSV per module, `reports\`)
- Infrastructure Inventory
- Security Findings
- Best Practice Recommendations
- PowerShell Assessment Toolkit

---

## Technologies

- Microsoft Active Directory
- Windows Server
- PowerShell
- DNS
- DHCP
- DFS Replication
- Group Policy
- Active Directory Certificate Services
- Kerberos
- LDAP
- Microsoft Entra ID / Microsoft Graph

---

## Project Status

✅ Core toolkit complete (Foundation, Infrastructure, and Hybrid Identity assessments, plus the executive HTML dashboard). Ongoing refinement of checks and reporting.

This repository is part of a broader Microsoft Infrastructure portfolio focused on enterprise assessment, automation, hybrid identity, and cloud migration.

This is the **public portfolio version** of the toolkit, designed to be run safely against any environment and demoed with fictitious data. It intentionally omits environment-specific configuration.

---

## Roadmap

See [ROADMAP.md](ROADMAP.md) for the full versioned roadmap.

---

## Author

Walter Campal

Senior Infrastructure Engineer

Microsoft Infrastructure | Azure | Hybrid Identity | PowerShell Automation
