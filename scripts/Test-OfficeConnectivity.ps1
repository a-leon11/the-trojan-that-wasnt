<#
.SYNOPSIS
    Read-only network checks for Microsoft 365 / Office install errors
    such as 0-2015 (2250), 30183-1011 or 30088-1015.

.DESCRIPTION
    Checks, for each Office endpoint the installer needs:
      * DNS resolution (and flags fake answers such as 0.0.0.0 / 127.0.0.1)
      * TCP connection on port 443, separately for IPv4 and IPv6
      * a real HTTPS request with TLS 1.2 (any HTTP status counts as reachable)

    Then checks the usual local suspects:
      * hosts file entries that mention Microsoft/Office
      * the WinHTTP proxy (separate from the proxy in Settings)
      * enabled outbound firewall BLOCK rules and their remote addresses
      * routes that send Microsoft address ranges somewhere odd
      * TLS protocol overrides in the SCHANNEL registry key

    Nothing is changed. Run it in an Administrator PowerShell for complete results.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Test-OfficeConnectivity.ps1
#>
[CmdletBinding()]
param(
    [string[]]$Endpoints = @(
        'mrodevicemgr.officeapps.live.com',   # Office release service (the one that failed in this case)
        'officecdn.microsoft.com',            # Office download CDN (used by the Deployment Tool)
        'config.office.com',
        'ecs.office.com',
        'login.microsoftonline.com',
        'www.microsoft.com'                   # control: should always work
    ),
    [int]$TcpTimeoutMs = 5000,
    [int]$HttpTimeoutSec = 20
)

# Windows PowerShell 5.1 does not use TLS 1.2 by default; Microsoft servers require it.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Test-Tcp {
    param([string]$Address, [int]$Port = 443, [int]$TimeoutMs = 5000)
    $ip = [Net.IPAddress]::Parse($Address)
    $client = New-Object Net.Sockets.TcpClient($ip.AddressFamily)
    try {
        $task = $client.ConnectAsync($ip, $Port)
        return ($task.Wait($TimeoutMs) -and $client.Connected)
    } catch {
        return $false
    } finally {
        $client.Dispose()
    }
}

function Test-Https {
    param([string]$HostName, [int]$TimeoutSec = 20)
    try {
        $r = Invoke-WebRequest -Uri "https://$HostName/" -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
        return "OK (HTTP $($r.StatusCode))"
    } catch [System.Net.WebException] {
        # A server that answers with 3xx/4xx/5xx is still reachable.
        if ($_.Exception.Response) {
            return "OK (HTTP $([int]$_.Exception.Response.StatusCode))"
        }
        return "FAIL: $($_.Exception.Status)"
    } catch {
        if ($_.Exception.Response) {
            return "OK (HTTP $([int]$_.Exception.Response.StatusCode))"
        }
        return "FAIL: $($_.Exception.Message)"
    }
}

function Write-Section($title) {
    Write-Host ""
    Write-Host "=== $title ===" -ForegroundColor Cyan
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Not running as Administrator: firewall and registry checks may be incomplete." -ForegroundColor Yellow
}

# ---------------------------------------------------------------- endpoints
Write-Section "Office endpoints"
$results = foreach ($ep in $Endpoints) {
    Write-Host "Testing $ep ..." -NoNewline
    $v4 = @(); $v6 = @(); $dnsNote = ''
    try {
        $addrs = [Net.Dns]::GetHostAddresses($ep)
        $v4 = $addrs | Where-Object { $_.AddressFamily -eq 'InterNetwork' }   | ForEach-Object { $_.IPAddressToString }
        $v6 = $addrs | Where-Object { $_.AddressFamily -eq 'InterNetworkV6' } | ForEach-Object { $_.IPAddressToString }
        if ($v4 | Where-Object { $_ -in '0.0.0.0', '127.0.0.1' }) { $dnsNote = 'FAKE ADDRESS (blocked by hosts/DNS filter)' }
    } catch {
        $dnsNote = 'DNS FAILED'
    }

    $v4ok = if ($v4) { if ($v4 | Where-Object { Test-Tcp $_ 443 $TcpTimeoutMs }) { 'yes' } else { 'NO' } } else { '-' }
    $v6ok = if ($v6) { if ($v6 | Where-Object { Test-Tcp $_ 443 $TcpTimeoutMs }) { 'yes' } else { 'NO' } } else { '-' }
    $https = if ($dnsNote -eq 'DNS FAILED') { 'skipped' } else { Test-Https $ep $HttpTimeoutSec }
    Write-Host " done"

    [pscustomobject]@{
        Endpoint = $ep
        IPv4     = ($v4 -join ', ')
        'TCP v4' = $v4ok
        'TCP v6' = $v6ok
        HTTPS    = $https
        Note     = $dnsNote
    }
}
$results | Format-Table -AutoSize -Wrap | Out-Host

# ---------------------------------------------------------------- hosts file
Write-Section "hosts file entries mentioning Microsoft/Office"
$hostsPath = Join-Path $env:windir 'System32\drivers\etc\hosts'
$hostsHits = Get-Content $hostsPath -ErrorAction SilentlyContinue |
    Where-Object { $_ -notmatch '^\s*#' -and $_ -match 'microsoft|office|live\.com|msftconnect|windowsupdate' }
if ($hostsHits) { $hostsHits | ForEach-Object { Write-Host "  $_" -ForegroundColor Red } }
else { Write-Host "  None (clean)." -ForegroundColor Green }

# ---------------------------------------------------------------- WinHTTP proxy
Write-Section "WinHTTP proxy (used by the Office installer)"
$proxy = (netsh winhttp show proxy) -join ' '
if ($proxy -match 'Direct access') { Write-Host "  Direct access (no proxy)." -ForegroundColor Green }
else { Write-Host "  $proxy" -ForegroundColor Red }

# ---------------------------------------------------------------- firewall
Write-Section "Enabled outbound firewall BLOCK rules"
$blockRules = Get-NetFirewallRule -Direction Outbound -Action Block -Enabled True -ErrorAction SilentlyContinue
if ($blockRules) {
    $blockRules | ForEach-Object {
        $addr = ($_ | Get-NetFirewallAddressFilter).RemoteAddress -join ','
        $app  = ($_ | Get-NetFirewallApplicationFilter).Program
        [pscustomobject]@{ Rule = $_.DisplayName; Program = $app; RemoteAddress = $addr }
    } | Format-Table -AutoSize -Wrap | Out-Host
} else {
    Write-Host "  None." -ForegroundColor Green
}

# ---------------------------------------------------------------- routes
Write-Section "Routes for common Microsoft 365 ranges (13.x, 20.x, 40.x, 52.x)"
$routes = Get-NetRoute -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.DestinationPrefix -match '^(13|20|40|52)\.' }
if ($routes) { $routes | Select-Object DestinationPrefix, NextHop, InterfaceAlias | Format-Table -AutoSize | Out-Host }
else { Write-Host "  None (normal)." -ForegroundColor Green }

# ---------------------------------------------------------------- TLS
Write-Section "TLS protocol overrides (SCHANNEL)"
$schannel = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'
$tls = Get-ChildItem $schannel -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
    $p = Get-ItemProperty $_.PSPath
    if ($null -ne $p.Enabled -or $null -ne $p.DisabledByDefault) {
        [pscustomobject]@{ Key = $_.PSPath -replace '^.*Protocols\\', ''; Enabled = $p.Enabled; DisabledByDefault = $p.DisabledByDefault }
    }
}
if ($tls) { $tls | Format-Table -AutoSize | Out-Host } else { Write-Host "  No overrides (Windows defaults)." -ForegroundColor Green }

# ---------------------------------------------------------------- verdict
Write-Section "Reading the results"
$mro = $results | Where-Object Endpoint -eq 'mrodevicemgr.officeapps.live.com'
$cdn = $results | Where-Object Endpoint -eq 'officecdn.microsoft.com'
if ($mro -and $mro.HTTPS -like 'FAIL*' -and $cdn -and $cdn.HTTPS -like 'OK*') {
    Write-Host "The Office release service is unreachable but the Office CDN works." -ForegroundColor Yellow
    Write-Host "This matches error 0-2015 (2250). First check https://status.cloud.microsoft for an outage"
    Write-Host "(that was the cause in the case this repo describes). Then wait, or install with the"
    Write-Host "Office Deployment Tool (odt/configuration.xml), which gets its version data from the CDN instead."
} elseif (($results | Where-Object { $_.HTTPS -like 'FAIL*' }).Count -ge ($results.Count - 1)) {
    Write-Host "Almost nothing is reachable: check the general internet connection, VPN, proxy or antivirus web filter." -ForegroundColor Yellow
} else {
    Write-Host "No obvious network block. Run Get-C2RLogErrors.ps1 to see the exact failing step." -ForegroundColor Green
}
