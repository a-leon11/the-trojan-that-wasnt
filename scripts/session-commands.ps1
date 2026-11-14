<#
    session-commands.ps1
    =====================================================================
    Every PowerShell command used in "The Trojan That Wasn't", in the
    order they were run, with the results I got (anonymized).

    THIS IS A REFERENCE LOG, NOT A SCRIPT TO RUN TOP TO BOTTOM.
    Copy the lines you need into an *Administrator* PowerShell window,
    one at a time. Most of it only reads settings. The two lines that
    change something (adding and removing a hosts-file entry) are marked
    with  !!! CHANGES SYSTEM !!!

    For the automated, read-only versions see:
      Get-C2RLogErrors.ps1        reads the Office installer logs
      Test-OfficeConnectivity.ps1 network checks
    =====================================================================
#>
return   # stops this file from running if someone executes it by accident


# ---------------------------------------------------------------------
# Chapter 6, Test 1: DNS, TCP 443, WinHTTP proxy, firewall block rules
# ---------------------------------------------------------------------
"--- DNS ---"; Resolve-DnsName mrodevicemgr.officeapps.live.com -ErrorAction SilentlyContinue | Select Name,IPAddress | Format-Table
# RESULT: resolved to real Microsoft addresses (52.110.2.x and 2603:1063:...). DNS is fine.

"--- CONNECTION ---"; Test-NetConnection mrodevicemgr.officeapps.live.com -Port 443 | Select ComputerName,RemoteAddress,TcpTestSucceeded | Format-Table
# RESULT: "TCP connect to (52.110.2.x : 443) failed" for all four IPv4 addresses. TcpTestSucceeded False.

"--- WINHTTP PROXY ---"; netsh winhttp show proxy
# RESULT: "Direct access (no proxy server)."  The installer uses WinHTTP, not the Settings proxy.

"--- FIREWALL BLOCK RULES ---"; Get-NetFirewallRule -Direction Outbound -Action Block -Enabled True | Select DisplayName,Group | Format-Table -AutoSize
# RESULT: "No matching MSFT_NetFirewallRule objects found". There are zero outbound block rules, which is good.


# ---------------------------------------------------------------------
# Chapter 6, Test 2: control site, routes, the Office server over IPv6
# ---------------------------------------------------------------------
"--- GENERAL 443 TEST ---"; Test-NetConnection www.microsoft.com -Port 443 | Select RemoteAddress,TcpTestSucceeded | Format-Table
# RESULT: True (over IPv6). General HTTPS connectivity works.

"--- ROUTES TO 52.110 ---"; route print | findstr "52.110 52.108 52.109"
# RESULT: nothing. No "black-hole" routes.

"--- BLOCK RULES + ADDRESSES ---"; Get-NetFirewallRule -Direction Outbound -Action Block -Enabled True | ForEach-Object { [pscustomobject]@{Rule=$_.DisplayName; Remote=(($_ | Get-NetFirewallAddressFilter).RemoteAddress -join ',')} } | Format-Table -AutoSize -Wrap
# RESULT: none.

"--- OFFICE SERVER OVER IPv6 ---"; Test-NetConnection 2603:1063:2001:529::365:ff1 -Port 443 | Select RemoteAddress,TcpTestSucceeded | Format-Table
# RESULT: True. The server accepts TCP over IPv6 but not IPv4.

"--- OTHER IPv4 SITES ---"; "1.1.1.1","142.250.190.78","officecdn.microsoft.com" | ForEach-Object { Test-NetConnection $_ -Port 443 -WarningAction SilentlyContinue | Select ComputerName,RemoteAddress,TcpTestSucceeded } | Format-Table
# (This one got pasted onto the end of another command and never ran properly. See the mistakes below.)


# ---------------------------------------------------------------------
# Chapter 6, Experiment: pin the server to its working IPv6 address
# !!! CHANGES SYSTEM !!!  Remove it afterwards (see Chapter 7, Step 1)
# ---------------------------------------------------------------------
Add-Content -Path "$env:windir\System32\drivers\etc\hosts" -Value "`r`n2603:1063:2001:529::365:ff1 mrodevicemgr.officeapps.live.com"
ipconfig /flushdns
Test-NetConnection mrodevicemgr.officeapps.live.com -Port 443
# RESULT: RemoteAddress 2603:1063:2001:529::365:ff1, TcpTestSucceeded True.
#         The installer STILL failed: the HTTPS request timed out after ~16 s.
#
# MISTAKES I MADE HERE (so you don't):
#   * Commands pasted onto the end of a previous line ran as nonsense like "Format-TableAdd-Content".
#     Paste ONE line, press Enter, wait.
#   * "The requested operation requires elevation": the window wasn't "Administrator: Windows PowerShell".


# ---------------------------------------------------------------------
# Chapter 6, Test 3a: a real HTTPS request (and the PowerShell 5.1 trap)
# ---------------------------------------------------------------------
try { $r = Invoke-WebRequest "https://mrodevicemgr.officeapps.live.com/mrodevicemgrsvc/api/v2/C2RReleaseData/492350f6-3a01-4f97-b9c0-c7c6ddf67d60?aud=Production&ch=CC&ring=Production" -UseBasicParsing -TimeoutSec 30; "OK: " + $r.StatusCode + " bytes " + $r.RawContentLength } catch { "FAIL: " + $_.Exception.Message }; netsh int tcp show global | findstr /i "Receive"; netsh interface ipv6 show subinterfaces
# RESULT: "FAIL: The underlying connection was closed: An unexpected error occurred on a receive."
#         Receive Window Auto-Tuning: normal. Wi-Fi MTU: 1492 (normal for PPPoE broadband).
# TRAP:   Windows PowerShell 5.1 doesn't use TLS 1.2 by default, so this failure was partly my own test's fault.


# ---------------------------------------------------------------------
# Chapter 6, Test 3b: same request with TLS 1.2, plus Windows' TLS settings
# ---------------------------------------------------------------------
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; try { $r = Invoke-WebRequest "https://mrodevicemgr.officeapps.live.com/mrodevicemgrsvc/api/v2/C2RReleaseData/492350f6-3a01-4f97-b9c0-c7c6ddf67d60?aud=Production&ch=CC&ring=Production" -UseBasicParsing -TimeoutSec 30; "OK: " + $r.StatusCode + " bytes " + $r.RawContentLength } catch { "FAIL: " + $_.Exception.Message }; Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols' -Recurse -ErrorAction SilentlyContinue | Get-ItemProperty | Select PSChildName,Enabled,DisabledByDefault | Format-Table; Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp' -ErrorAction SilentlyContinue | Select DefaultSecureProtocols
# RESULT: "FAIL: The operation has timed out."  No SCHANNEL overrides. TLS on Windows is fine.
#         Opening the same URL in Chrome:  ERR_CONNECTION_TIMED_OUT.  The server isn't answering.


# ---------------------------------------------------------------------
# Chapter 7, Step 1: remove the hosts pin
# !!! CHANGES SYSTEM !!!  (restores the hosts file)
# ---------------------------------------------------------------------
$h="$env:windir\System32\drivers\etc\hosts"; (Get-Content $h) | Where-Object {$_ -notmatch 'mrodevicemgr'} | Set-Content $h; ipconfig /flushdns
# RESULT: "Successfully flushed the DNS Resolver Cache."


# ---------------------------------------------------------------------
# Chapter 7, Step 3: install with the Office Deployment Tool
# ---------------------------------------------------------------------
cd "$env:USERPROFILE\Downloads\ODT"
.\setup.exe /configure configuration.xml
# RESULT: the window closed within seconds (normal: it hands off to Click-to-Run),
#         the log shows v64.cab downloaded from officecdn.microsoft.com, AvailBld 16.0.20527.20196,
#         then "Please stay online while Microsoft 365 and Office downloads". Installed.


# ---------------------------------------------------------------------
# Not PowerShell, but used in Chapter 3 to review a Task Manager screen recording
# ---------------------------------------------------------------------
# ffmpeg -i recording.mp4 -vf "fps=1,scale=1456:-1" frames/g_%02d.png
#
# And in Chapter 5 to read the UTF-16 Office logs on Linux/macOS:
# iconv -f UTF-16LE -t UTF-8 DESKTOP-XXXXXXX-YYYYMMDD-HHMMa.log > log.txt
# grep -n -E 'HttpTransportError|"Success": false|ShowErrorCode' log.txt
