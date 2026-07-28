<#
.SYNOPSIS
    Retrieves DNS health for all Domain Controllers in the forest.

.AUTHOR
    Walter Campal
    Horizon Labs

.VERSION
    1.0.0
#>

function Get-HLDNSHealth {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$DomainControllers
    )

    $Results = @()

    foreach ($DC in $DomainControllers) {

        Write-Verbose "Checking DNS health on $($DC.HostName)"

        #--------------------------------------------------
        # DNS Service
        #--------------------------------------------------

        try {

            $Service = Get-Service `
                -ComputerName $DC.HostName `
                -Name DNS `
                -ErrorAction Stop

            $Results += New-HealthResult `
                -Category "DNS" `
                -Check "DNS Service" `
                -Target $DC.HostName `
                -Status $(if ($Service.Status -eq "Running") { "Healthy" } else { "Critical" }) `
                -Severity $(if ($Service.Status -eq "Running") { "Info" } else { "High" }) `
                -Message "Service Status: $($Service.Status)" `
                -Recommendation $(if ($Service.Status -ne "Running") { "Start the DNS Server service on this Domain Controller and investigate why it stopped." } else { "" })

        }
        catch {

            $Results += New-HealthResult `
                -Category "DNS" `
                -Check "DNS Service" `
                -Target $DC.HostName `
                -Status "Critical" `
                -Severity "High" `
                -Message $_.Exception.Message `
                -Recommendation "Verify connectivity and the DNS Server service on this Domain Controller."
        }

        #--------------------------------------------------
        # Resolve own hostname
        #--------------------------------------------------

        try {

            Resolve-DnsName `
                -Name $DC.HostName `
                -ErrorAction Stop | Out-Null

            $Results += New-HealthResult `
                -Category "DNS" `
                -Check "Hostname Resolution" `
                -Target $DC.HostName `
                -Status "Healthy" `
                -Message "Hostname resolved successfully."

        }
        catch {

            $Results += New-HealthResult `
                -Category "DNS" `
                -Check "Hostname Resolution" `
                -Target $DC.HostName `
                -Status "Critical" `
                -Severity "Medium" `
                -Message $_.Exception.Message `
                -Recommendation "Investigate DNS zone replication scope and this Domain Controller's DNS registration."
        }

        #--------------------------------------------------
        # LDAP SRV Record
        #--------------------------------------------------

        try {

            Resolve-DnsName `
                -Name "_ldap._tcp.dc._msdcs.$($DC.Domain)" `
                -Type SRV `
                -ErrorAction Stop | Out-Null

            $Results += New-HealthResult `
                -Category "DNS" `
                -Check "LDAP SRV Record" `
                -Target $DC.HostName `
                -Status "Healthy" `
                -Message "_ldap._tcp.dc._msdcs resolved."

        }
        catch {

            $Results += New-HealthResult `
                -Category "DNS" `
                -Check "LDAP SRV Record" `
                -Target $DC.HostName `
                -Status "Critical" `
                -Severity "High" `
                -Message $_.Exception.Message `
                -Recommendation "Confirm the netlogon service registered SRV records for this Domain Controller (nltest /dsregdns)."
        }

        #--------------------------------------------------
        # Kerberos SRV Record
        #--------------------------------------------------

        try {

            Resolve-DnsName `
                -Name "_kerberos._tcp.$($DC.Domain)" `
                -Type SRV `
                -ErrorAction Stop | Out-Null

            $Results += New-HealthResult `
                -Category "DNS" `
                -Check "Kerberos SRV Record" `
                -Target $DC.HostName `
                -Status "Healthy" `
                -Message "_kerberos._tcp resolved."

        }
        catch {

            $Results += New-HealthResult `
                -Category "DNS" `
                -Check "Kerberos SRV Record" `
                -Target $DC.HostName `
                -Status "Critical" `
                -Severity "High" `
                -Message $_.Exception.Message `
                -Recommendation "Confirm the netlogon service registered SRV records for this Domain Controller (nltest /dsregdns)."
        }

    }

    return $Results
}
