# Changelog

## v1.1.0

### Added

- Foundation modules: Site Topology, Replication Status, SYSVOL/DFSR Health, DNS Assessment, GPO Inventory, Security Baseline
- Infrastructure modules: DHCP, Certificate Services, File Services, DFS Namespace Health, Event Log Analysis, Windows Services
- Hybrid Identity modules: Entra Connect Status, PTA Agent Status, Cloud Sync Status, Entra ID Assessment, Conditional Access Review
- `New-DemoData.ps1` — generates fictitious assessment data for safe demos/portfolio use
- `New-AssessmentDashboard.ps1` — builds a single-file HTML executive dashboard with an overall Infrastructure Health Score and per-area status
- `Start-InfrastructureAssessment.ps1` and `Start-HybridIdentityAssessment.ps1` orchestrators
- Pre-generated sample report in `examples/sample-report/`

### Changed

- `Common.ps1` now centralizes report path resolution, module availability checks (`Test-RequiredModule`), and CSV export (`Export-AssessmentCsv`) for every module
- All existing modules updated to use the shared error handling and export helpers

## v1.0.0

### Added

- Initial repository structure
- Professional documentation
- Assessment roadmap
- Domain Controller Inventory, Forest Information, Domain Information, FSMO Roles modules
