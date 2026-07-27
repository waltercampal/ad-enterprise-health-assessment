<#
.SYNOPSIS
    Exports assessment results to CSV.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.1.0
#>

function Export-Report {

    param(
        [Parameter(Mandatory)]
        $InputObject,

        [Parameter(Mandatory)]
        [string]$FileName
    )

    $Path = Join-Path ".\reports" $FileName

    $InputObject |
        Export-Csv `
            -Path $Path `
            -NoTypeInformation `
            -Encoding UTF8

    Write-Host ""
    Write-Host "Report exported: $Path" -ForegroundColor Green
}