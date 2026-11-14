# The Trojan That Wasn't

### How I spent an afternoon hunting a trojan that was already gone, while the real culprit was a Microsoft outage

> One laptop, one sketchy Office download, one very real trojan alert, and about four hours of me being convinced my PC was still infected. Spoiler: the reason Office wouldn't install was on the other side of the internet. 💀

This is a **troubleshooting case study from my own PC**. It covers every alert, every wrong guess, every PowerShell command and every result, written so you can follow along and **try to solve it before I do** (it's not hard to beat me here, ngl).

I'm sharing it because the way I got it wrong is more useful than the fix itself. I missed the obvious thing for hours, and that's part of the story.

If you're here because of **Microsoft 365 error `0-2015 (2250)`**, skip to the [toolkit](#the-toolkit).

---

## TL;DR

I installed Office from an **unofficial installer**. Bad idea. Microsoft Defender flagged **`Trojan:Win32/Bearfoos.B!ml`**. I cleaned it up and went to install Office the legit way, and **every official installer failed with `0-2015 (2250)`**. Obviously the trojan had broken something, right? So I went full detective mode: processes, startup items, temp folders, the hosts file, the firewall, routes, TLS settings, IPv4 vs IPv6. **Everything was clean.** The installer's own logs pointed at one Microsoft server that never answered. A workaround with the **Office Deployment Tool** finally installed Office. Only afterwards did I find out that **Microsoft was having a worldwide Microsoft 365 outage that same day** (incident **EX1550543**).

The trojan was real. It just wasn't the reason Office wouldn't install. Two separate problems, one very confused me.

---

## Read it as a story (or as an exercise)

Each chapter ends with **🧠 Stop and think** questions. Try answering before you open the spoiler.

| # | Chapter | What happens |
|---|---|---|
| 1 | [The Alert](chapters/01-the-alert.md) | Defender flags `Bearfoos.B!ml`, and my first instinct is to ask how to allow it. Great start. |
| 2 | [What It Really Was](chapters/02-what-it-really-was.md) | The folder name gives it away, and I find out the threat had been *allowed*. |
| 3 | [The Cleanup](chapters/03-the-cleanup.md) | Removing the threat and sweeping the whole PC, including a "suspicious" process that turned out to be Microsoft's own. |
| 4 | [The Install That Wouldn't](chapters/04-the-install-that-wouldnt.md) | The legit installer fails with `0-2015 (2250)`. So do all the generic fixes. |
| 5 | [Reading the Logs](chapters/05-reading-the-logs.md) | The installer's hidden logs name the real failure: a timeout to one server. |
| 6 | [Network Forensics](chapters/06-network-forensics.md) | PowerShell, DNS, TCP, IPv4 vs IPv6, a hosts-file experiment, and a PowerShell 5.1 trap. |
| 7 | [The Workaround](chapters/07-the-workaround.md) | The Office Deployment Tool takes a different road, and it works. |
| 8 | [Plot Twist](chapters/08-plot-twist.md) | It was a Microsoft outage the whole time. What I should have done first. |

---

## The 10 lessons I learned the hard way

1. **`!ml` in a Defender name means machine learning**: a behaviour-based guess. It *can* be a false positive, but a hit on an unofficial installer almost never is.
2. **Never "Allow on device" for something you can't verify.** That one click turns a blocked threat into one that may have run.
3. **If something ran, change your passwords from a different device.** Info-stealers take saved passwords and session cookies.
4. **A random-looking `.exe` in `%TEMP%` isn't automatically malware.** The Microsoft Store runs installers under random names. Check the digital signature before you panic. (I panicked.)
5. **Correlation isn't causation.** "Trojan happened, then Office broke" felt like one story. It was two.
6. **Generic error codes hide real ones.** `0-2015 (2250)` told me nothing. The log said `HttpTransportError 0x80072ee2` to one specific host.
7. **Office writes detailed logs to `%TEMP%`.** Read them *before* trying random fixes.
8. **Test one variable at a time**: another network, IPv4 vs IPv6, a raw TCP connection vs a real HTTPS request, PowerShell vs a browser.
9. **Windows PowerShell 5.1 doesn't use TLS 1.2 by default**, so your own test can lie to you.
10. **Check the provider's status page first.** It would have saved me most of the afternoon. Big L.

---

## The toolkit

If you just want to fix `0-2015 (2250)`:

| File | What it does |
|---|---|
| [`scripts/Get-C2RLogErrors.ps1`](scripts/Get-C2RLogErrors.ps1) | Reads the Office installer logs in `%TEMP%` and tells you in plain English which server failed and why. **Read-only.** |
| [`scripts/Test-OfficeConnectivity.ps1`](scripts/Test-OfficeConnectivity.ps1) | Tests the Office endpoints (DNS, TCP over IPv4 and IPv6, real HTTPS) and the usual local suspects: hosts file, WinHTTP proxy, firewall block rules, routes, TLS overrides. **Read-only.** |
| [`scripts/session-commands.ps1`](scripts/session-commands.ps1) | Every PowerShell command I ran, in order, with comments and the results I got. |
| [`odt/configuration.xml`](odt/configuration.xml) | The Office Deployment Tool config that installed Microsoft 365 when nothing else would. |

**Quick path:**

1. Check **[Microsoft 365 Status](https://status.cloud.microsoft)** or Downdetector. Seriously, do this first. Learn from my pain.
2. Run `powershell -ExecutionPolicy Bypass -File .\scripts\Get-C2RLogErrors.ps1`.
3. If it reports a network timeout to `mrodevicemgr.officeapps.live.com`, either wait for Microsoft to fix it or install with the Office Deployment Tool ([Chapter 7](chapters/07-the-workaround.md)).

---

## Privacy note

Usernames, computer names, machine and session IDs, IP addresses that identify my connection, accounts, school, ISP and personal apps are removed or replaced with placeholders such as `<user>` and `DESKTOP-XXXXXXX`. The name of the unofficial release is deliberately left out so this repo doesn't advertise it.

## Disclaimer

This is one machine on one day. Your problem may have a different cause, and the logs will tell you which. Read any script before you run it. The two diagnostic scripts only read settings; nothing in them changes your system.

## License

[MIT](LICENSE)
