# Correct-SystemTime

`Correct-SystemTime` is a PowerShell function that looks up a computer in
Active Directory, checks whether it is reachable, compares its clock with the
computer running the function, and offers to set the remote clock when the
times differ. It displays the result and does not change the remote time
without interactive confirmation.

## Prerequisites

- Windows PowerShell 5.1.
- The ActiveDirectory PowerShell module, available with the Remote Server
  Administration Tools (RSAT).
- Permission to query the specified Active Directory domain or directory
  server.
- PowerShell remoting (WinRM) enabled and reachable on the target.
- An account allowed to connect by PowerShell remoting and to change the
  system time on the target.
- ICMP echo requests allowed to the target for the connectivity check.

## Usage

Dot-source the script to load the function, then call it:

```powershell
. .\Function_Correct-SystemTime.PS1
Correct-SystemTime -ComputerName 'Computer01' -Domain 'contoso.com'
```

`-ComputerName` is required and identifies the computer object to look up in
Active Directory. `-Domain` specifies the Active Directory domain or directory
server used for that lookup; it defaults to `SANUK`.

The function compares the clocks using a two-second tolerance. If the remote
clock differs, it prompts you to confirm before setting it. Enter `Y` to
continue; any other response leaves the clock unchanged.

## Limitations

- The initiating computer's clock is treated as correct. Verify that it is
  synchronized and that the target uses a compatible time zone before
  proceeding.
- The function changes the remote system clock; it does not configure time
  zones or replace a domain/NTP time synchronization policy.
- The connectivity check relies on ICMP. A computer that blocks ping will be
  reported as unreachable even if other network services are available.
- This is an interactive function and requires a prompt response before it
  changes a clock.

Originally written by Steven Wight. For background, see
[Got the Time?](https://www.joshooaj.com/blog/2025/02/27/got-the-time/).
