function Write-Step {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Host ""
    Write-Host "[INFO] $Message" -ForegroundColor Cyan

}

function Write-Success {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Host "[OK] $Message" -ForegroundColor Green

}

function Write-ErrorMessage {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Host "[ERROR] $Message" -ForegroundColor Red

}

function Export-AssessmentCsv {

    [CmdletBinding()]
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

function New-HealthResult {

    <#
    .SYNOPSIS
        Creates a standardized ADEHAT Health Result object.

    .DESCRIPTION
        All Health modules must return objects created with this function.
        This ensures a consistent output model across the entire toolkit.

    .PARAMETER Category
        Functional category (Replication, DNS, SYSVOL, etc.)

    .PARAMETER Check
        Name of the health check.

    .PARAMETER Target
        Object evaluated.

    .PARAMETER Status
        Health status.

    .PARAMETER Severity
        Impact level.

    .PARAMETER Message
        Result description.

    .PARAMETER Recommendation
        Suggested corrective action.
    #>

    [CmdletBinding()]
    param(

        [Parameter(Mandatory)]
        [string]$Category,

        [Parameter(Mandatory)]
        [string]$Check,

        [Parameter(Mandatory)]
        [string]$Target,

        [Parameter(Mandatory)]
        [ValidateSet(
            'Healthy',
            'Warning',
            'Critical',
            'Skipped'
        )]
        [string]$Status,

        [ValidateSet(
            'Info',
            'Low',
            'Medium',
            'High'
        )]
        [string]$Severity = 'Info',

        [Parameter(Mandatory)]
        [string]$Message,

        [string]$Recommendation = ''

    )

    $Result = [PSCustomObject]@{

        PSTypeName     = 'ADEHAT.HealthResult'

        Category       = $Category

        Check          = $Check

        Target         = $Target

        Status         = $Status

        Severity       = $Severity

        Message        = $Message

        Recommendation = $Recommendation

    }

    return $Result

}