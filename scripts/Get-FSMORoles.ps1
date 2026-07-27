<#
.SYNOPSIS
    Retrieves all FSMO role holders in the Active Directory Forest.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.2.1
#>

Import-Module ActiveDirectory

$Forest = Get-ADForest

$Results = @()

# Forest FSMO Roles

$Results += [PSCustomObject]@{
    Scope  = "Forest"
    Domain = "-"
    Role   = "Schema Master"
    Server = $Forest.SchemaMaster
}

$Results += [PSCustomObject]@{
    Scope  = "Forest"
    Domain = "-"
    Role   = "Domain Naming Master"
    Server = $Forest.DomainNamingMaster
}

# Domain FSMO Roles

foreach ($DomainName in $Forest.Domains)
{
    $Domain = Get-ADDomain `
        -Identity $DomainName `
        -Server $DomainName

    $Results += [PSCustomObject]@{
        Scope  = "Domain"
        Domain = $Domain.DNSRoot
        Role   = "PDC Emulator"
        Server = $Domain.PDCEmulator
    }

    $Results += [PSCustomObject]@{
        Scope  = "Domain"
        Domain = $Domain.DNSRoot
        Role   = "RID Master"
        Server = $Domain.RIDMaster
    }

    $Results += [PSCustomObject]@{
        Scope  = "Domain"
        Domain = $Domain.DNSRoot
        Role   = "Infrastructure Master"
        Server = $Domain.InfrastructureMaster
    }
}

$Results |
    Export-Csv `
        -Path ".\reports\FSMORoles.csv" `
        -NoTypeInformation `
        -Encoding UTF8

return $Results