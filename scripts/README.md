# Scripts

PowerShell assessment modules, invoked directly or via the `Start-*.ps1` orchestrators in the repo root.

- `Common/Common.ps1` — shared logging, module checks, and CSV export helpers used by every module.
- `Get-*.ps1` — one module per assessment area (Foundation, Infrastructure, Hybrid Identity). See [`docs/Assessment-Methodology.md`](../docs/Assessment-Methodology.md) for the full list and what each one checks.
- `New-DemoData.ps1` — generates fictitious assessment data for demos/portfolio use.
- `New-AssessmentDashboard.ps1` — builds the executive HTML dashboard from `reports\*.csv`.
