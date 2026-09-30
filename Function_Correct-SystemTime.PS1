Function Correct-SystemTime{
    <#
    .SYNOPSIS
    Function to correct wrong time and date on remote machines
    by Steven Wight
    .DESCRIPTION
    Looks up the target computer in Active Directory, checks that it is online, compares its
    clock to the local machine's clock and, after confirmation, corrects the remote clock using
    PowerShell remoting.
    .PARAMETER ComputerName
    The name of the remote computer whose system time should be checked/corrected. Mandatory.
    .PARAMETER Domain
    The Active Directory domain (server) to query when looking up the computer. Defaults to "SANUK".
    .EXAMPLE
    Correct-SystemTime -ComputerName Computer01
    .EXAMPLE
    Correct-SystemTime -ComputerName Computer01 -Domain CONTOSO
    .Notes
    This assumes the correct time and date on the machine it's being run from # ADD IN CHECK FOR SERVICE W32TIME - START/RESTART !?!
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String] $ComputerName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String] $Domain = "SANUK"
    )

    #Clear Variables encase function has been used before in session (never know!)   
    $Computer = $AdCheck = $PathTest = $TimeAndDate = $RemoteTimeAndDate = $null
    
   # Get Computer info from AD
   try{
        $Computer = (Get-ADComputer $ComputerName -properties DNSHostname,description,OperatingSystem -server $Domain -ErrorAction stop)
        $AdCheck = $true
    }Catch{
        Write-Host -ForegroundColor Red "Machine $($ComputerName) not found in AD domain $($Domain): $($_.Exception.Message)"
        $AdCheck = $false
    }

    # Check machine is online 
    if($True -eq $AdCheck){   
        # -Quiet returns $false (rather than throwing) when the machine doesn't respond
        $PathTest = Test-Connection -Computername $Computer.DNSHostname -BufferSize 16 -Count 1 -Quiet
    } #End of If ADcheck is True

    #if Machine is online
    if($True -eq $PathTest) {
    
        #Output machine is online to the console
        Write-host -ForegroundColor Green "$($ComputerName) is online"
         
        #Get remote machines Time and date
        try{
            $RemoteTimeAndDate = Invoke-Command -ComputerName $Computer.DNSHostname -ScriptBlock { Get-Date } -ErrorAction Stop
        }Catch{
            Write-Host -ForegroundColor Red "Unable to retrieve the time from $($ComputerName). Check PowerShell remoting/WinRM and permissions: $($_.Exception.Message)"
            return
        }
        
        #get local machines date and time
        $TimeAndDate = Get-Date
        
        #if time is out (allow a small tolerance for command/query latency)
        if([Math]::Abs(($RemoteTimeAndDate - $TimeAndDate).TotalSeconds) -ge 2){
            
            Write-Host ""
            Write-Host -ForegroundColor RED "$($ComputerName) time is out"
            Write-Host -ForegroundColor RED "Remote Time - $($RemoteTimeAndDate)"
            Write-Host -ForegroundColor RED "Local Time  - $($TimeAndDate)"
            Write-Host ""

            $Continue = Read-Host -Prompt 'Do you wish to correct? -  Press Y to continue'

            if ("Y" -eq $Continue.ToUpper()) {
                
                Write-Host ""
                Write-Warning -Message "Correcting time on $($ComputerName)"
                Write-Host ""

                #get local machines date and time
                $TimeAndDate = Get-Date

                #Correct time on remote machine
                try{
                    $RemoteTimeAndDate = Invoke-Command -ComputerName $Computer.DNSHostname -ScriptBlock {
                        Set-Date -Date $using:TimeAndDate -ErrorAction Stop
                        Get-Date
                    } -ErrorAction Stop
                }Catch{
                    Write-Host ""
                    Write-Host -ForegroundColor RED "Failed to set the time on $($ComputerName). Check that the account has permission to set the system clock: $($_.Exception.Message)"
                    Write-Host ""
                    return
                }

                #confirm time and date was set correctly, allowing a small tolerance for latency
                if([Math]::Abs(($RemoteTimeAndDate - $TimeAndDate).TotalSeconds) -lt 2){
            
                    #output if successful
                    Write-Host ""
                    Write-Host -ForegroundColor Green "$($ComputerName) time was successfully corrected"
                    Write-Host ""

                }else{

                    #output if unsuccessful and what the difference is
                    Write-Host ""
                    Write-Host -ForegroundColor RED "$($ComputerName) issue correcting time"
                    Write-Host -ForegroundColor RED "Remote Time - $($RemoteTimeAndDate)"
                    Write-Host -ForegroundColor RED "Local Time  - $($TimeAndDate)"
                    Write-Host ""

                }
            }
             
        }else{
            
            #output if time is okay
            Write-Host ""
            Write-Host -ForegroundColor Green "$($ComputerName) time is correct"
            Write-Host ""  
        
        }                                                                                               

    }else{#If machine wasn't online 
        
        #Output machine is online to the console
        Write-host -ForegroundColor Red "$($ComputerName) is offline"

    }# End of If
}# end of Function
