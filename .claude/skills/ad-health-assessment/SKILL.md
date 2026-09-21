---
name: ad-health-assessment
description: Use when diagnosing or fixing problems in on-prem Active Directory — Domain Controllers, replication, FSMO, SYSVOL/DFSR, DNS, Group Policy, security baseline, event logs — or when running/extending this repo's Enterprise AD Health Assessment toolkit (Start-EnterpriseAssessment.ps1 and scripts/*.ps1). Also covers basic Entra Connect sync health (read-only) as the on-prem/cloud sync boundary.
---

# AD Health Assessment

Extiende el toolkit de este repo (`Start-EnterpriseAssessment.ps1`, `scripts/*.ps1`, `scripts/Common/Common.ps1`) para diagnosticar y — con confirmación — remediar problemas de Active Directory on-prem.

## Regla de confirmación (no negociable)

- **Solo lectura / diagnóstico** (Get-*, repadmin /showrepl, dcdiag, exportar reportes): ejecutar directo, sin pedir confirmación.
- **Escritura o remediación contra un entorno real** (cualquier Set-/Remove-/New-, forzar replicación, reiniciar servicios, tocar GPOs): mostrar el comando exacto y su impacto, y **pedir confirmación explícita antes de correrlo**. Nunca asumir "ya que estamos, lo arreglo".
- **Decisiones de arquitectura/estrategia** (ej. migrar FSMO, cambiar topología de sitios, retirar un DC): no ejecutar nada — presentar opciones y consultar.
- Todo output de diagnóstico va a `reports/` como CSV (usar `Export-AssessmentCsv` de `Common.ps1`), igual que los scripts existentes.

## Flujo típico

1. El usuario describe el síntoma en lenguaje natural (ej. "la replicación entre DC1 y DC2 está atrasada", "SYSVOL no replica", "un usuario no puede loguearse en una sucursal").
2. Mapear el síntoma al área de diagnóstico correspondiente (ver `references/checks-catalog.md` para comandos concretos por área: Forest/Domain, FSMO, Replicación, SYSVOL/DFSR, DNS, GPO, Seguridad, Event Logs, Entra Connect).
3. Correr los checks de solo lectura relevantes, reutilizando o extendiendo los scripts existentes en `scripts/` en vez de duplicar lógica.
4. Diagnosticar la causa probable y proponer la corrección. Si es remediación real, pedir confirmación antes de ejecutar.
5. Si el hallazgo es nuevo y recurrente, ofrecer agregarlo como script permanente en `scripts/` (siguiendo el estilo de `Get-FSMORoles.ps1`: bloque de comentarios SYNOPSIS/AUTHOR/VERSION, `Import-Module ActiveDirectory`, objeto `[PSCustomObject]`, export a CSV, mensaje de éxito con `Write-Success`).

## Convenciones de código del repo (mantenerlas)

- Mismo estilo de header de comentario (`SYNOPSIS`, `AUTHOR: Walter Campal / Horizon Labs`, `VERSION`).
- Usar las funciones de `scripts/Common/Common.ps1` (`Write-Step`, `Write-Success`, `Write-ErrorMessage`, `Export-AssessmentCsv`) en lugar de reimplementar logging/export.
- Si se agrega un script nuevo, registrarlo también en `Start-EnterpriseAssessment.ps1` y tildarlo en `ROADMAP.md` / `FEATURES.md`.

## Fuera de alcance de este skill

- Entra ID / M365 / Graph / Conditional Access a fondo, Exchange Online, Teams, SharePoint, SCCM, SCOM, TFS/GitLab, remediación de vulnerabilidades cross-stack → viven en el sistema de skills laboral separado (repo privado aparte, no este). Este skill solo cubre AD on-prem y el chequeo básico de sincronización de Entra Connect como frontera.

Ver `references/checks-catalog.md` para el catálogo de comandos por área antes de diagnosticar algo fuera de lo ya cubierto por los scripts existentes.
