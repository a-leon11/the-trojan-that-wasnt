# Chapter 8: Plot Twist

[← Chapter 7](07-the-workaround.md) · [Back to README](../README.md)

---

A little while after Office finally installed, I went looking for answers and found them on the news:

> **Microsoft had an outage. 😂**

Yep.

## The outage

That same day, **12 November 2026**, Microsoft acknowledged a large Microsoft 365 connectivity incident, tracked as **EX1550543**:

- It started in the **Americas** in the early afternoon (Eastern Time), and Microsoft later said it could affect users **in any region**.
- **Exchange Online / Outlook, Teams, SharePoint Online, Copilot** and other Microsoft 365 services were affected. Outage trackers recorded tens of thousands of reports.
- Microsoft attributed it to part of its infrastructure being under **heavy load across multiple regions**, and redistributed traffic to recover.

My installer failures started that same afternoon. The release service that kept timing out (`mrodevicemgr.officeapps.live.com`) is part of the same Microsoft 365 cloud. **The silent server wasn't a trojan leftover, an activator firewall rule or a broken PC. It was Microsoft.**

The outage also blocked my next step: signing in with my school account, and getting an Outlook verification code, had to wait until Microsoft recovered.

I spent four hours interrogating my own PC for a crime it didn't commit. Sorry, laptop. 🫡

## So was the trojan scare pointless?

**No.** Both stories were real:

| Story | Real? | Handled? |
|---|---|---|
| An unofficial installer with an activator dropped something Defender called `Trojan:Win32/Bearfoos.B!ml`, which "executes commands from an attacker", and I'd set it to **allowed** | ✅ Yes | Removed, files deleted, system swept, passwords to change |
| Office wouldn't install because of the trojan | ❌ No | It was a Microsoft 365 outage |

The mistake was **linking them**. Something bad happened, then something broke, so my brain wrote one story. That's classic **confirmation bias**: every new symptom got read as "the trojan's still here", and I went looking for proof on my PC instead of first asking whether the problem was outside it.

## What I should have done, in order

1. **Check the status page:** [status.cloud.microsoft](https://status.cloud.microsoft), Microsoft 365 Status on X, or Downdetector. **30 seconds.**
2. **Read the installer log** ([Chapter 5](05-reading-the-logs.md)). It named the exact failing server in the first few minutes.
3. **Test from a different device and network.** If my phone can't load the URL either, it isn't my PC.
4. *Only then* start pulling the PC apart.

To be fair to myself: a real trojan had been on the machine hours earlier, and I was panicking. The deep check wasn't wasted, either. It confirmed nothing persistent was left behind, which is worth knowing after something like Chapter 2. But the install problem would have been solved in minutes with step 1.

## What I got right and wrong

**What worked:**
- I took the alert seriously once I saw the threat had been *allowed*, and treated the PC as possibly compromised.
- I checked the scary random `.exe` before killing it. It was Microsoft's own installer.
- I went to the **installer logs** instead of guessing forever.
- I caught the **PowerShell 5.1 TLS** trap instead of trusting a misleading result.
- I found a **working workaround** (the ODT) while the outage was still going.

**What didn't:**
- **I never checked Microsoft's service status**, even after the logs showed a Microsoft server timing out from two different networks. That's the first thing any help desk would have done.
- I spent time on Windows fixes (the uninstall tool, Smart App Control, registry keys) before reading the logs.

My takeaway: once you've decided what the cause is, every symptom starts to look like proof. I said "the trojan broke something" and ran with it for hours. Question the frame.

## The end

- ✅ Trojan removed, no persistence found.
- ✅ Microsoft 365 installed legitimately through the Office Deployment Tool.
- ✅ The temporary hosts entry reverted.
- ⏳ Passwords changed from another device, plus an offline Defender scan. *(Do this if anything like Chapter 2 ever happens to you.)*
- 📦 This repo, so the next person with `0-2015 (2250)` checks the status page first. W.

---

## 🧠 Final question

If you hit `0-2015 (2250)` tomorrow, what are your first three moves?

<details>
<summary><b>Answer</b></summary>

1. Check **Microsoft 365 Status** / Downdetector.
2. Run [`Get-C2RLogErrors.ps1`](../scripts/Get-C2RLogErrors.ps1) to see which server or step failed.
3. If it's a network timeout to `mrodevicemgr.officeapps.live.com`: wait it out, or install with the [Office Deployment Tool](07-the-workaround.md).

</details>

---

[← Chapter 7](07-the-workaround.md) · [Back to README](../README.md)
