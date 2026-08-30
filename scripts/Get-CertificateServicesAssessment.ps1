<#
.SYNOPSIS
    Assesses Active Directory Certificate Services (AD CS) deployment.

.DESCRIPTION
    Locates registered Enrollment Services (Certification Authorities) in
    the Configuration partition and reports their host, CA type, and
    reachability.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    0.1.0
#>

. "$PSScriptRoot\Common\Common.ps1"

Write-Step "Collecting Certificate Services Assessment..."

if (!(Test-RequiredModule -ModuleName ActiveDirectory)) { return }

try {

    $ConfigNC = (Get-ADRootDSE).configurationNamingContext
    $EnrollmentServicesPath = "CN=Enrollment Services,CN=Public Key Services,CN=Services,$ConfigNC"

    $CAs = Get-ADObject -SearchBase $EnrollmentServicesPath -Filter * -Properties dNSHostName, cACertificate, displayName -ErrorAction Stop |
        Where-Object { $_.ObjectClass -eq "pKIEnrollmentService" }

    $CAReport = foreach ($CA in $CAs) {

        $Reachable = if ($CA.dNSHostName) {
            if (Test-Connection -ComputerName $CA.dNSHostName -Count 1 -Quiet) { "Yes" } else { "No" }
        }
        else {
            "Unknown"
        }

        [PSCustomObject]@{

            CAName         = $CA.displayName
            Server         = $CA.dNSHostName
            HasCertificate = [bool]$CA.cACertificate
            Reachable      = $Reachable

        }

    }

    $CAReport | Format-Table -AutoSize

    Export-AssessmentCsv -Data $CAReport -Name "CertificateServices"

    if (($CAReport | Measure-Object).Count -eq 0) {
        Write-WarningMessage "No Certification Authorities found registered in Active Directory."
    }

}
catch {
    Write-ErrorMessage "Failed to collect Certificate Services Assessment: $($_.Exception.Message)"
}
