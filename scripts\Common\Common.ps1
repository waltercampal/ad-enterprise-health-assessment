function Write-Step {

    param(
        [string]$Message
    )

    Write-Host ""
    Write-Host "[INFO] $Message" -ForegroundColor Cyan

}

function Write-Success {

    param(
        [string]$Message
    )

    Write-Host "[OK] $Message" -ForegroundColor Green

}

function Write-ErrorMessage {

    param(
        [string]$Message
    )

    Write-Host "[ERROR] $Message" -ForegroundColor Red

}

function Export-AssessmentCsv {

    param(

        [Parameter(Mandatory)]
        $Data,

        [Parameter(Mandatory)]
        [string]$Name

    )

    $Data |
    Export-Csv `
        -Path ".\reports\$Name.csv" `
        -NoTypeInformation `
        -Encoding UTF8

}
