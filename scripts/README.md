# Scripts

PowerShell assessment scripts, organized by phase:

- `Common/` - shared functions (logging, CSV export, the `New-HealthResult`
  standard output model).
- `Get-*.ps1` (this folder) - Discovery: forest, domain, FSMO, Domain
  Controller and Site inventory.
- `Health/` - independent Health checks (`Get-HL*Health.ps1`). Each returns
  an array of `New-HealthResult` objects. See
  [`docs/Assessment-Methodology.md`](../docs/Assessment-Methodology.md) for
  the contract and how to add a new check.
- `Reporting/` - aggregates Health results into the Infrastructure Score,
  the HTML report, and the executive summary.

Run the full assessment with
[`Start-EnterpriseAssessment.ps1`](../Start-EnterpriseAssessment.ps1) from
the repository root.
