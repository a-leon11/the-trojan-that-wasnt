# Chapter 6: Network Forensics

[← Chapter 5](05-reading-the-logs.md) · [Back to README](../README.md) · [Next: The Workaround →](07-the-workaround.md)

---

My working theory: *something on this PC is blocking `mrodevicemgr.officeapps.live.com`.* This chapter is every PowerShell test I ran to prove or disprove it, with the real (anonymized) output. All of them only **read** settings, except the hosts-file experiment, which is clearly marked.

> Run these in **PowerShell as Administrator**: Start → type *PowerShell* → right-click → **Run as administrator**. The window title must start with `Administrator:`. (Foreshadowing.)

---

## Test 1: DNS, TCP, proxy, firewall

```powershell
"--- DNS ---"; Resolve-DnsName mrodevicemgr.officeapps.live.com -ErrorAction SilentlyContinue | Select Name,IPAddress | Format-Table
"--- CONNECTION ---"; Test-NetConnection mrodevicemgr.officeapps.live.com -Port 443 | Select ComputerName,RemoteAddress,TcpTestSucceeded | Format-Table
"--- WINHTTP PROXY ---"; netsh winhttp show proxy
"--- FIREWALL BLOCK RULES ---"; Get-NetFirewallRule -Direction Outbound -Action Block -Enabled True | Select DisplayName,Group | Format-Table -AutoSize
```

Result:

```text
--- DNS ---
Name                                            IPAddress
----                                            ---------
mrodevicemgr.officeapps.live.com
mrodevicemgr-prod-defaultgeo.trafficmanager.net
atm.office.mira.tm.svc.cloud.microsoft          2603:1063:2001:529::365:ff1
atm.office.mira.tm.svc.cloud.microsoft          52.110.2.147
atm.office.mira.tm.svc.cloud.microsoft          52.110.2.194
atm.office.mira.tm.svc.cloud.microsoft          52.110.2.136
atm.office.mira.tm.svc.cloud.microsoft          52.110.2.182

--- CONNECTION ---
WARNING: TCP connect to (52.110.2.182 : 443) failed
WARNING: TCP connect to (52.110.2.136 : 443) failed
WARNING: TCP connect to (52.110.2.194 : 443) failed
WARNING: TCP connect to (52.110.2.147 : 443) failed
ComputerName                     RemoteAddress TcpTestSucceeded
mrodevicemgr.officeapps.live.com 52.110.2.182             False

--- WINHTTP PROXY ---
    Direct access (no proxy server).

--- FIREWALL BLOCK RULES ---
Get-NetFirewallRule : No matching MSFT_NetFirewallRule objects found ...
```

**Reading it:**

- **DNS is fine.** Real Microsoft addresses, not `0.0.0.0` or `127.0.0.1`. No hosts-file or DNS-filter block.
- **TCP over IPv4 fails** to all four addresses.
- **No proxy.** That matters because the Office installer uses the **WinHTTP** proxy, which is separate from the one in Settings.
- *"No matching ... objects found"* looks like an error, but it means **there are zero outbound block rules**, so no activator firewall rules.

## Test 2: routes, a control site, IPv6

```powershell
"--- GENERAL 443 TEST ---"; Test-NetConnection www.microsoft.com -Port 443 | Select RemoteAddress,TcpTestSucceeded | Format-Table
"--- ROUTES TO 52.110 ---"; route print | findstr "52.110 52.108 52.109"
"--- OFFICE SERVER OVER IPv6 ---"; Test-NetConnection 2603:1063:2001:529::365:ff1 -Port 443 | Select RemoteAddress,TcpTestSucceeded | Format-Table
```

```text
--- GENERAL 443 TEST ---
RemoteAddress           TcpTestSucceeded
2600:xxxx:...:356e                  True

--- ROUTES TO 52.110 ---
(nothing)

--- OFFICE SERVER OVER IPv6 ---
RemoteAddress                TcpTestSucceeded
2603:1063:2001:529::365:ff1              True
```

**Plot thickens:** `www.microsoft.com` works (over IPv6), there are no fake "black-hole" routes, and **the Office server accepts a TCP connection over IPv6** while refusing over IPv4.

New theory: Windows (or the installer) picks the **broken IPv4 path**. Big if true.

## Experiment: pin the server to its working IPv6 address ⚠️ (changes a file)

To force the working path, I added one line to the hosts file:

```powershell
Add-Content -Path "$env:windir\System32\drivers\etc\hosts" -Value "`r`n2603:1063:2001:529::365:ff1 mrodevicemgr.officeapps.live.com"
ipconfig /flushdns
Test-NetConnection mrodevicemgr.officeapps.live.com -Port 443
```

### Two mistakes I made along the way (you'll probably make them too)

1. **Pasted commands glued together.** I pasted several commands right after an earlier line, so PowerShell saw things like `Format-TableAdd-Content` and ran nothing. **Paste one line, press Enter, wait.**
2. **Not running as admin.** `ipconfig /flushdns` answered *"The requested operation requires elevation."* Editing the hosts file needs an **Administrator** window. Skill issue, honestly.

Done properly:

```text
ComputerName     : mrodevicemgr.officeapps.live.com
RemoteAddress    : 2603:1063:2001:529::365:ff1
RemotePort       : 443
InterfaceAlias   : Wi-Fi
TcpTestSucceeded : True
```

**TCP worked!** I ran the installer again… and it **failed again with `0-2015 (2250)`.** 🫠 The new log showed the same timeout after about 16 seconds. The connection opened, but the HTTPS request still never got an answer.

## Test 3: a real HTTPS request (and a PowerShell trap)

A TCP connection only proves a port accepts connections. I needed to see whether the **web service** actually answers.

First attempt:

```powershell
try { $r = Invoke-WebRequest "https://mrodevicemgr.officeapps.live.com/mrodevicemgrsvc/api/v2/C2RReleaseData/492350f6-3a01-4f97-b9c0-c7c6ddf67d60?aud=Production&ch=CC&ring=Production" -UseBasicParsing -TimeoutSec 30; "OK: " + $r.StatusCode } catch { "FAIL: " + $_.Exception.Message }
netsh int tcp show global | findstr /i "Receive"
netsh interface ipv6 show subinterfaces
```

```text
FAIL: The underlying connection was closed: An unexpected error occurred on a receive.
Receive-Side Scaling State          : enabled
Receive Window Auto-Tuning Level    : normal
Receive Segment Coalescing State    : enabled

       MTU  ...  Interface
      1492  ...  Wi-Fi
```

> ⚠️ **The trap:** *"An unexpected error occurred on a receive"* in **Windows PowerShell 5.1** is the classic symptom of PowerShell using **TLS 1.0/1.1 by default**. Microsoft servers require TLS 1.2. My own test was lying to me. Caught it, fixed it.

TCP auto-tuning "normal" and an MTU of 1492 (typical for PPPoE broadband) were both normal, so no tweak-tool damage there.

Second attempt, with TLS 1.2 forced on, plus a check that Windows' own TLS settings hadn't been tampered with:

```powershell
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
try { $r = Invoke-WebRequest "https://mrodevicemgr.officeapps.live.com/mrodevicemgrsvc/api/v2/C2RReleaseData/492350f6-3a01-4f97-b9c0-c7c6ddf67d60?aud=Production&ch=CC&ring=Production" -UseBasicParsing -TimeoutSec 30; "OK: " + $r.StatusCode } catch { "FAIL: " + $_.Exception.Message }
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols' -Recurse -ErrorAction SilentlyContinue | Get-ItemProperty | Select PSChildName,Enabled,DisabledByDefault | Format-Table
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp' -ErrorAction SilentlyContinue | Select DefaultSecureProtocols
```

```text
FAIL: The operation has timed out.

DefaultSecureProtocols
----------------------
```

- **Timeout** again, this time with a correct test.
- **No TLS overrides** in SCHANNEL. Windows' encryption settings were untouched.

## Test 4: take Windows out of the equation

Last test: open the same URL in **Chrome**, which uses its own network and TLS stack instead of Windows':

```
This site can't be reached
mrodevicemgr.officeapps.live.com took too long to respond.
ERR_CONNECTION_TIMED_OUT
```

Chrome timed out too.

## Where this left me

| Suspect | Status |
|---|---|
| hosts file / DNS block | ❌ ruled out |
| WinHTTP proxy | ❌ ruled out |
| Firewall rules | ❌ ruled out (there were none) |
| Fake routes | ❌ ruled out |
| TLS disabled | ❌ ruled out |
| TCP tuning / MTU | ❌ ruled out (normal) |
| Home network / ISP | ❌ ruled out (hotspot failed too) |
| Windows' network stack | ❌ ruled out (Chrome failed too) |
| **The server itself** | ⬅ the only thing left |

My conclusion: the server wasn't answering my PC over any route, so this was almost certainly on Microsoft's side. Instead of digging further, I looked for a way around it.

---

## 🧠 Stop and think

1. Why was the IPv6 TCP success misleading?
2. Which single test in this chapter was the strongest evidence against "my PC is blocking it"?

<details>
<summary><b>Answers</b></summary>

1. A TCP handshake is often answered by a load balancer or edge server in front of the actual service. "Port 443 accepts connections" doesn't mean "the service behind it is healthy." Only a **real HTTPS request** tests that, and it timed out.
2. **Chrome timing out.** Chrome brings its own TLS and doesn't use WinHTTP, so it bypasses most of what an activator or tweak tool could break. Combined with the hotspot test, that leaves almost no room for a local cause. Add *"check the status page"* and the case closes in five minutes.

</details>

---

[← Chapter 5](05-reading-the-logs.md) · [Back to README](../README.md) · [Next: The Workaround →](07-the-workaround.md)
