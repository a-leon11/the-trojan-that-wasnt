<#
.SYNOPSIS
    Finds the real reason a Microsoft 365 / Office Click-to-Run install failed.

.DESCRIPTION
    The Office installer only shows a generic code such as 0-2015 (2250). The
    actual cause is written to Click-to-Run logs in %TEMP%, named like
    COMPUTERNAME-YYYYMMDD-HHMM.log (UTF-16 text, one JSON-ish event per line).

    This script reads those logs and prints:
      * HTTP transport failures (which server the installer could not reach,
        and the WinHTTP error code), with a plain-English explanation
      * activities that ended with "Success": false and a non-zero Result.Code
      * any error dialog the installer showed

    It only reads files. It changes nothing.

.PARAMETER LogFolder
    Folder that holds the Click-to-Run logs. Defaults to the current user's %TEMP%.

.PARAMETER Latest
    Only analyse the newest N log files. Default: all of them.

.EXAMPLE
    .\Get-C2RLogErrors.ps1

.EXAMPLE
    .\Get-C2RLogErrors.ps1 -Latest 2
#>
[CmdletBinding()]
param(
    [string]$LogFolder = $env:TEMP,
    [int]$Latest = 0
)

# Common WinHTTP / network errors seen in Click-to-Run logs.
$knownErrors = @{
    '0x80072ee2' = 'WinHTTP timeout: the server never answered in time.'
    '0x80072efd' = 'Cannot connect to the server (refused or blocked).'
    '0x80072efe' = 'Connection to the server was aborted.'
    '0x80072ee7' = 'Server name could not be resolved (DNS problem).'
    '0x80072f7d' = 'Secure channel (TLS) error.'
    '0x80072f8f' = 'Certificate/security error (check the PC clock and TLS settings).'
    '0x80072f06' = 'Certificate name does not match (possible interception/proxy).'
    '0x80072eff' = 'Connection was reset.'
}

# C2R log names: MACHINE-YYYYMMDD-HHMM.log or ...HHMMa.log
$logs = Get-ChildItem -Path $LogFolder -Filter '*.log' -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^.+-\d{8}-\d{4}[a-z]?\.log$' } |
    Sort-Object LastWriteTime

if ($Latest -gt 0) { $logs = $logs | Select-Object -Last $Latest }

if (-not $logs) {
    Write-Host "No Click-to-Run logs found in $LogFolder." -ForegroundColor Yellow
    Write-Host "Run the Office installer once, then run this script again."
    return
}

$summary = @()

foreach ($log in $logs) {
    Write-Host ""
    Write-Host ("=== {0}  ({1:yyyy-MM-dd HH:mm}) ===" -f $log.Name, $log.LastWriteTime) -ForegroundColor Cyan

    # Logs are UTF-16 LE; Get-Content -Encoding Unicode reads them correctly.
    $lines = Get-Content -Path $log.FullName -Encoding Unicode -ErrorAction SilentlyContinue
    $found = $false

    foreach ($line in $lines) {
        $time = if ($line.Length -ge 23) { $line.Substring(11, 12) } else { '' }

        # 1) Network failures: which URL, which error code.
        if ($line -match "requestUrl:'(?<url>https?://[^']+?)\s*,\s*Error:(?<err>0x[0-9a-fA-F]+)") {
            $url  = $Matches['url']
            $err  = $Matches['err'].ToLower()
            $host_ = ([uri]($url -replace '\s.*$','')).Host
            $why  = if ($knownErrors.ContainsKey($err)) { $knownErrors[$err] } else { 'Unknown network error.' }
            Write-Host ("[{0}] NETWORK  {1}  {2}" -f $time, $host_, $err) -ForegroundColor Red
            Write-Host ("           {0}" -f $why)
            $summary += [pscustomobject]@{ Log = $log.Name; Type = 'Network'; Detail = "$host_ $err"; Meaning = $why }
            $found = $true
            continue
        }

        # 2) Activities that failed with a non-zero result code.
        if ($line -match '"Name": "(?<name>[^"]+)".*"Success": false.*"Result\.Code": (?<code>\d+)' -and $Matches['code'] -ne '0') {
            Write-Host ("[{0}] FAILED   {1}  (Result.Code {2})" -f $time, $Matches['name'], $Matches['code']) -ForegroundColor Yellow
            $summary += [pscustomobject]@{ Log = $log.Name; Type = 'Failed step'; Detail = $Matches['name']; Meaning = "Result.Code $($Matches['code'])" }
            $found = $true
            continue
        }

        # 3) The error dialog itself.
        if ($line -match 'ShowErrorCodePrereqFailureDialog|Showing Failure Dialog') {
            Write-Host ("[{0}] DIALOG   The installer showed its error window here." -f $time) -ForegroundColor Yellow
            $found = $true
        }
    }

    if (-not $found) {
        Write-Host "No errors found in this log." -ForegroundColor Green
    }
}

if ($summary) {
    Write-Host ""
    Write-Host "=== Summary ===" -ForegroundColor Cyan
    $summary | Sort-Object Type, Detail -Unique | Format-Table -AutoSize -Wrap | Out-Host

    if ($summary | Where-Object { $_.Detail -like 'mrodevicemgr.officeapps.live.com*' }) {
        Write-Host "The installer could not reach mrodevicemgr.officeapps.live.com (Office release service)." -ForegroundColor Yellow
        Write-Host "Workaround: install with the Office Deployment Tool, which reads version data from"
        Write-Host "officecdn.microsoft.com instead. See odt/configuration.xml and the README."
    }
}
