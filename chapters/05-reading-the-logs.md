# Chapter 5: Reading the Logs

[← Chapter 4](04-the-install-that-wouldnt.md) · [Back to README](../README.md) · [Next: Network Forensics →](06-network-forensics.md)

---

This is where things turned. Instead of trying fix number 47, I went into my `%TEMP%` folder and pulled out the files the Office installer had been quietly writing the whole time.

## Where Office keeps its diary

Every Click-to-Run install attempt writes logs to `%TEMP%`:

```
%TEMP%\DESKTOP-XXXXXXX-20261112-1350.log
%TEMP%\DESKTOP-XXXXXXX-20261112-1350a.log
%TEMP%\DESKTOP-XXXXXXX-20261112-1401.log
%TEMP%\DESKTOP-XXXXXXX-20261112-1401a.log
%TEMP%\DESKTOP-XXXXXXX-20261112-1403.log   ← the Microsoft Store attempt
```

Format: `COMPUTERNAME-YYYYMMDD-HHMM.log`. They're **UTF-16 text**, one event per line, mostly telemetry. Each is a few hundred KB, which is way too much to scroll through in Notepad (I tried; it was painful). Searching them with a script works much better.

This is how I searched them (Linux/macOS or WSL):

```bash
iconv -f UTF-16LE -t UTF-8 DESKTOP-XXXXXXX-20261112-1350a.log > 1350a.txt
grep -n -E 'HttpTransportError|"Success": false|ShowErrorCode' 1350a.txt
```

Or on Windows, with the script from this repo:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Get-C2RLogErrors.ps1
```

## What the log said

Lightly trimmed, with IDs removed:

```text
13:51:12.593  Click-To-Run Non Task Error  Monitorable  MRO::Load
  "ErrorCode": 30183,
  "ErrorType": "HttpTransportError",
  "ErrorMessage": "HttpTransportError (DmsClient::MakeDmsWebRequest:
      {message:'request->sendStream'
       requestUrl:'https://mrodevicemgr.officeapps.live.com/mrodevicemgrsvc/api/v2/
                   C2RReleaseData/492350f6-3a01-4f97-b9c0-c7c6ddf67d60
                   ?aud=Production&ch=CC&ring=Production&omid=<machine id>
      , Error:0x80072ee2)",
  "ContextData": "Failed to fetch MRO information from DMS"

13:51:12.597  Activity  ActivityEnded
  "Name": "Office.ClickToRun.UniversalBootstrapper.Execute3",
  "Duration": 42197359,            ← about 42 seconds of waiting
  "Success": false,
  "Result.Code": 2250,
  "Data.ErrorMessage": "DMS is configured but failed to provide a version",
  "Data.ErrorDetails": "... This network connection does not exist."

13:51:12.598  Click-To-Run  ShowErrorCodePrereqFailureDialog
  "Header": "Couldn't install",
  "ErrorCode": "0-2015 (2250)"
```

## Decoding it

| Piece | Meaning |
|---|---|
| `mrodevicemgr.officeapps.live.com` | Microsoft's release service. The installer asks it *"which Office build should I install for this channel?"* |
| `C2RReleaseData/492350f6-...` | The **Current Channel** of Microsoft 365 Apps |
| `request->sendStream` | The request was sent, but no answer came back |
| `0x80072ee2` | `ERROR_WINHTTP_TIMEOUT`: the server **never answered in time** |
| `30183` / `HttpTransportError` | Office's internal code for "the HTTP request failed" |
| `DMS is configured but failed to provide a version` | No answer from the release service, so no version to install, so the install stops |
| `2250` → `0-2015 (2250)` | The generic code I was shown |

**Every single attempt** (the web installer twice, and the Microsoft Store install, which just hung at that step) failed in the same place, against the same server, with the same timeout.

Other Microsoft services in the same logs (configuration and experiment services such as `ecs.office.com`) **answered fine**. So my PC wasn't offline. It was one server being silent.

## The phone hotspot test

To rule out my router and ISP, I switched the PC to my **phone's hotspot** and tried again.

> "Still same problem with phone hotspot."

Different network, same failure. Two possibilities:

- **Something on my PC** is blocking that server. A trojan leftover? An activator's firewall rule?
- **The server itself** isn't answering, for everyone or for my region.

After Chapters 1 to 3, the first option felt *way* more likely. My brain had already decided the trojan did it. So I went deep into the PC's network stack.

---

## 🧠 Stop and think

1. You know exactly which host fails. What's the **cheapest possible test** to tell "my PC is blocking it" apart from "the server is down"?
2. What evidence already pointed at the server instead of the PC?

<details>
<summary><b>Answers</b></summary>

1. **Open the same URL on a completely different device on a different network**, like a phone on mobile data, and **check the provider's status page or Downdetector**. Both take under a minute. I had the phone test in mind, but my PC investigation moved faster than it, and I didn't check the status page until the very end. 🙃
2. It failed on **two different networks**, everything else from Microsoft worked, and the failure was a **timeout** (silence) rather than a refusal or a DNS block. Activator blocks usually show up as hosts-file entries (`0.0.0.0 ...`) or firewall rules, and both were already ruled out.

</details>

---

[← Chapter 4](04-the-install-that-wouldnt.md) · [Back to README](../README.md) · [Next: Network Forensics →](06-network-forensics.md)
