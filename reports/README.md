# Reports

This folder is the default output location for `Start-EnterpriseAssessment.ps1`.

When you run an assessment against a real environment, the toolkit writes the
live CSV/TXT/HTML results directly here (`reports/*.csv`, `reports/*.txt`,
`reports/*.html`). Those files are **git-ignored** (see `.gitignore`) because
they contain real hostnames, IP addresses, site topology and security
findings from your environment — they must never be committed or pushed.

## reports/samples/

[`reports/samples/`](samples/) contains fully anonymized, fictional sample
output (fictional forest `fabrikam.com`) with the same schema the toolkit
produces. These files **are** tracked in git and are safe to show publicly —
use them to see what a finished report looks like, or as reference when
building new Health modules, without needing a live Active Directory
environment.

Do not replace the files in `reports/samples/` with real data.
