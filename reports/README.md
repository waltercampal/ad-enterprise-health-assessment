# Reports

This is the default output folder for every assessment module: each one writes `reports\<ModuleName>.csv`, and `New-AssessmentDashboard.ps1` writes `reports\AssessmentDashboard.html` here.

Generated CSV/HTML files in this folder are git-ignored — they're runtime output, not something to commit. For a checked-in example you can browse without running anything, see [`examples/sample-report/`](../examples/sample-report/).
