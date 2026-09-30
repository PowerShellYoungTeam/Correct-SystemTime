function Correct-SystemTime {
    <#
    .SYNOPSIS
    Corrects the time on a remote computer after interactive confirmation.

    .DESCRIPTION
    Finds a computer in Active Directory, checks connectivity, compares its
    time with the initiating computer, and offers to set the remote time.
    The initiating computer's clock is treated as correct.

    .PARAMETER ComputerName
    The computer name to find in Active Directory.

    .PARAMETER Domain
    The Active Directory domain or directory server to query. Defaults to SANUK.

    .EXAMPLE
    Correct-SystemTime -ComputerName 'Computer01' -Domain 'contoso.com'

    .NOTES
    Requires the ActiveDirectory module and permission to query Active
    Directory. PowerShell remoting must be enabled on the remote computer,
    and the caller must have permission to change its system time.

    Originally written by Steven Wight.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $ComputerName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Domain = 'SANUK'
    )

    $timeToleranceSeconds = 2

    try {
        $computer = Get-ADComputer -Identity $ComputerName `
            -Properties DNSHostname, Description, OperatingSystem `
            -Server $Domain -ErrorAction Stop
    }
    catch {
        Write-Error "Unable to find '$ComputerName' in Active Directory using '$Domain'. Verify the computer name, domain, ActiveDirectory module, and directory access. Details: $($_.Exception.Message)"
        return
    }

    if ([string]::IsNullOrWhiteSpace($computer.DNSHostname)) {
        Write-Error "Active Directory did not return a DNS host name for '$ComputerName'. Verify the computer object's DNSHostname attribute."
        return
    }

    try {
        $isOnline = Test-Connection -ComputerName $computer.DNSHostname `
            -BufferSize 16 -Count 1 -Quiet -ErrorAction Stop
    }
    catch {
        Write-Error "Unable to check connectivity to '$($computer.DNSHostname)'. Verify DNS, network access, and that ICMP echo requests are allowed. Details: $($_.Exception.Message)"
        return
    }

    if (-not $isOnline) {
        Write-Error "'$ComputerName' did not respond to the connectivity check. Verify that it is online and reachable, and that ICMP echo requests are allowed."
        return
    }

    Write-Host -ForegroundColor Green "$ComputerName is online"

    try {
        $remoteTimeAndDate = Invoke-Command -ComputerName $computer.DNSHostname `
            -ScriptBlock { Get-Date } -ErrorAction Stop
    }
    catch {
        Write-Error "Unable to read the time from '$($computer.DNSHostname)'. Verify that PowerShell remoting/WinRM is enabled and that you have permission to connect. Details: $($_.Exception.Message)"
        return
    }

    $timeAndDate = Get-Date
    if ([Math]::Abs(($remoteTimeAndDate - $timeAndDate).TotalSeconds) -gt $timeToleranceSeconds) {
        Write-Host ''
        Write-Host -ForegroundColor Red "$ComputerName time is out"
        Write-Host -ForegroundColor Red "Remote Time - $(Get-Date -Date $remoteTimeAndDate -Format 'dddd MM/dd/yyyy HH:mm:ss')"
        Write-Host -ForegroundColor Red "Local Time  - $(Get-Date -Date $timeAndDate -Format 'dddd MM/dd/yyyy HH:mm:ss')"
        Write-Host ''

        $continue = Read-Host -Prompt 'Do you wish to correct? Press Y to continue'
        if ($continue -ine 'Y') {
            Write-Host "No changes made to $ComputerName."
            return
        }

        Write-Warning "Correcting time on $ComputerName"
        $timeAndDate = Get-Date

        try {
            $remoteTimeAndDate = Invoke-Command -ComputerName $computer.DNSHostname `
                -ScriptBlock {
                    Set-Date -Date $using:timeAndDate -ErrorAction Stop
                    Get-Date
                } -ErrorAction Stop
        }
        catch {
            Write-Error "Unable to set the time on '$($computer.DNSHostname)'. Verify PowerShell remoting access and that your account is permitted to change the remote system time. Details: $($_.Exception.Message)"
            return
        }

        if ([Math]::Abs(($remoteTimeAndDate - $timeAndDate).TotalSeconds) -le $timeToleranceSeconds) {
            Write-Host ''
            Write-Host -ForegroundColor Green "$ComputerName time was successfully corrected"
            Write-Host ''
        }
        else {
            Write-Host ''
            Write-Host -ForegroundColor Red "$ComputerName issue correcting time"
            Write-Host -ForegroundColor Red "Remote Time - $(Get-Date -Date $remoteTimeAndDate -Format 'dddd MM/dd/yyyy HH:mm:ss')"
            Write-Host -ForegroundColor Red "Local Time  - $(Get-Date -Date $timeAndDate -Format 'dddd MM/dd/yyyy HH:mm:ss')"
            Write-Host ''
        }
    }
    else {
        Write-Host ''
        Write-Host -ForegroundColor Green "$ComputerName time is correct"
        Write-Host ''
    }
}
