# Correct-SystemTime

`Correct-SystemTime` is a PowerShell function that checks whether a remote computer's system
clock matches the clock of the machine you run it from, and — after you confirm — corrects it
using PowerShell remoting.

## What it does

1. Looks up `-ComputerName` in Active Directory (via `Get-ADComputer`) to resolve its DNS hostname.
2. Checks that the computer is online (`Test-Connection`).
3. Compares the remote machine's current time to the local machine's current time.
4. If the times differ by 2 seconds or more, prompts you to confirm before changing anything.
5. On confirmation, uses `Invoke-Command` and `Set-Date` to set the remote clock to match the
   local clock, then re-checks the remote time to confirm the correction succeeded.

## Prerequisites

- **ActiveDirectory PowerShell module** (`RSAT-AD-PowerShell` / `Get-ADComputer`) installed and
  available on the machine running this function.
- **Permissions**:
  - Rights to query the target computer object in Active Directory.
  - Rights to set the system date/time on the remote computer (typically local Administrator
    rights on the target, or delegated permission to set system time).
- **PowerShell remoting / WinRM** enabled and reachable on the target computer (the function uses
  `Invoke-Command`, which requires WinRM to be configured and the appropriate firewall rules open).
- Windows PowerShell 5.1 (or later) on the machine running the function.

## Usage

```powershell
. .\Function_Correct-SystemTime.PS1

Correct-SystemTime -ComputerName <ComputerName> [-Domain <Domain>]
```

| Parameter      | Required | Default  | Description                                                                 |
|----------------|----------|----------|-------------------------------------------------------------------------------|
| `ComputerName` | Yes      | n/a      | Name of the computer (as known to AD) whose system time should be checked.  |
| `Domain`       | No       | `SANUK`  | The Active Directory domain/server used to look up `ComputerName` via `Get-ADComputer -Server`. |

### Example

```powershell
Correct-SystemTime -ComputerName Computer01
```

Checks `Computer01`'s clock against the local clock. If they differ, you'll be prompted:

```
Computer01 time is out
Remote Time - 01/01/2026 09:00:00
Local Time  - 01/01/2026 09:05:12

Do you wish to correct? -  Press Y to continue:
```

Press `Y` to set the remote clock to match the local clock, or any other key to leave it
unchanged.

### Example with a specific domain

```powershell
Correct-SystemTime -ComputerName Computer01 -Domain CONTOSO
```

## Limitations

- The function assumes the **local machine's clock is correct**; it always corrects the remote
  machine to match the local time, never the other way around.
- It is **interactive** — when a time difference is detected, it requires a `Y` confirmation at
  the prompt before making any change. It is not suitable for unattended/scheduled use as-is.
- `Set-Date` sets the remote machine's *local* time to the sending machine's *local* time value.
  If the local and remote machines are in **different time zones**, run this only when you intend
  the remote machine to adopt the local machine's time zone's clock time, or adjust accordingly.
- Time comparisons use a small (2 second) tolerance to account for command and clock-query
  latency; this is not a high-precision time sync tool (consider `w32tm`/NTP for that).
- Requires network connectivity, AD lookup rights, and PowerShell remoting to the target; any of
  these being unavailable will be reported with an error message and the function will stop for
  that computer.

## Reference

This function was inspired by / based on ideas from Josh Ohde's blog post:
https://www.joshooaj.com/blog/2025/02/27/got-the-time/
