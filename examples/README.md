# Examples

- **`sample-report/`** — a pre-generated example of the toolkit's output using fictitious data ("Contoso Manufacturing"). Open `sample-report/AssessmentDashboard.html` directly in a browser to see the executive dashboard without running PowerShell. The underlying CSVs are in `sample-report/reports/`.

To generate your own (real or fictitious) version:

```powershell
.\scripts\New-DemoData.ps1              # or run the real assessment modules
.\scripts\New-AssessmentDashboard.ps1
```
