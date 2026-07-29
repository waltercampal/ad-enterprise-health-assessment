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

function Get-HLCimInstance {

    <#
    .SYNOPSIS
        Wraps Get-CimInstance so a remote call can be made with an alternate
        credential.

    .DESCRIPTION
        Get-CimInstance's -ComputerName parameter set does not accept
        -Credential in this environment's CimCmdlets module (confirmed via
        Get-Command -Syntax against the real forest run). When a credential
        is supplied, this instead opens a CimSession with that credential
        and queries through it, closing the session afterward.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName,

        [Parameter(Mandatory)]
        [string]$ClassName,

        [string]$Filter,

        [System.Management.Automation.PSCredential]$Credential
    )

    $QuerySplat = @{
        ClassName   = $ClassName
        ErrorAction = 'Stop'
    }
    if ($Filter) { $QuerySplat['Filter'] = $Filter }

    if ($Credential) {
        $Session = New-CimSession -ComputerName $ComputerName -Credential $Credential -ErrorAction Stop
        try {
            return Get-CimInstance @QuerySplat -CimSession $Session
        }
        finally {
            Remove-CimSession -CimSession $Session -ErrorAction SilentlyContinue
        }
    }
    else {
        return Get-CimInstance @QuerySplat -ComputerName $ComputerName
    }

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