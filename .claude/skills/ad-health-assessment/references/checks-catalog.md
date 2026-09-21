# Catálogo de chequeos por área

Comandos de referencia (todos de solo lectura salvo que se indique lo contrario). Preferir extender los scripts existentes en `scripts/` antes de correr comandos sueltos.

## Forest / Domain (ya cubierto)
- `Get-ADForest`, `Get-ADDomain` → `scripts/Get-ForestInformation.ps1`, `scripts/Get-DomainInformation.ps1`

## FSMO (ya cubierto)
- `scripts/Get-FSMORoles.ps1`

## Domain Controller Inventory (ya cubierto)
- `scripts/Get-DomainControllerInventory.ps1`

## Replicación AD (pendiente en ROADMAP v1.0)
- `Get-ADReplicationPartnerMetadata -Target (Get-ADDomain).DNSRoot -Scope Domain`
- `Get-ADReplicationFailure -Target (Get-ADDomain).DNSRoot -Scope Domain`
- `repadmin /showrepl * /csv` (para exportar a CSV con el mismo patrón que los otros scripts)
- `repadmin /replsummary`
- Remediación (requiere confirmación): `repadmin /syncall /AdeP`

## SYSVOL / DFSR (pendiente)
- `dfsrmig /getmigrationstate`
- `Get-DfsrState`, `Get-DfsReplicatedFolder`
- Event log: IDs 4614, 4004, 5002 en el log "DFS Replication"

## DNS (pendiente)
- `Get-DnsServerZone`, `Get-DnsServerForwarder`
- `Resolve-DnsName` cruzado entre DCs para detectar inconsistencias
- `dcdiag /test:dns /v`

## Group Policy (pendiente)
- `Get-GPO -All`, `Get-GPOReport -All -ReportType Html`
- Detectar GPOs sin vincular, deshabilitadas, o con permisos rotos: `Get-GPPermission`

## Security Baseline (pendiente)
- `Get-ADDefaultDomainPasswordPolicy`
- `Get-ADUser -Filter {AdminCount -eq 1}` (cuentas privilegiadas)
- `Get-ADGroupMember "Domain Admins"`, `"Enterprise Admins"`, `"Schema Admins"`
- Kerberoasting/legacy: cuentas con SPN + cifrado débil (`msDS-SupportedEncryptionTypes`)

## Windows Server / Event Log (pendiente)
- `dcdiag /v` general
- `Get-WinEvent -LogName "Directory Service"` filtrando por nivel Error/Warning

## Entra Connect (frontera con hybrid identity — solo lectura acá)
- `Get-ADSyncScheduler` (próxima sincronización, si está habilitada)
- `Get-ADSyncConnectorRunStatus`
- `Get-ADSyncAutoUpgrade`
- Si aparecen errores de sync recurrentes o se necesita profundizar en Entra ID/Conditional Access → escalar al skill de hybrid identity del sistema laboral (repo separado), no expandir acá.

## Reporting (pendiente v1.0/v3.0)
- Consolidar todos los CSV de `reports/` en un HTML único (Infrastructure Score) — ver `ROADMAP.md` v3.0.
