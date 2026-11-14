# Chapter 7: The Workaround

[← Chapter 6](06-network-forensics.md) · [Back to README](../README.md) · [Next: Plot Twist →](08-plot-twist.md)

---

If one server won't answer, use a tool that doesn't need it.

## The Office Deployment Tool

The **Office Deployment Tool (ODT)** is Microsoft's official command-line installer for IT departments. The useful difference here: to work out which Office version to install, it can read the list of available builds from a file on the **Office CDN** (`officecdn.microsoft.com`) instead of asking the release service that kept ghosting me.

The CDN was reachable the whole time.

## Step 1: undo the hosts experiment

The IPv6 pin from Chapter 6 didn't help, and a stale hosts entry could break Office updates later, so I removed it (Administrator PowerShell):

```powershell
$h="$env:windir\System32\drivers\etc\hosts"; (Get-Content $h) | Where-Object {$_ -notmatch 'mrodevicemgr'} | Set-Content $h; ipconfig /flushdns
```

## Step 2: the configuration file

I put this file in my `Downloads\ODT` folder ([`odt/configuration.xml`](../odt/configuration.xml)):

```xml
<Configuration>
  <Add OfficeClientEdition="64" Channel="Current">
    <Product ID="O365ProPlusRetail">
      <Language ID="en-us" />
      <Language ID="es-mx" />
      <ExcludeApp ID="Groove" />
      <ExcludeApp ID="Lync" />
    </Product>
  </Add>
  <Updates Enabled="TRUE" Channel="Current" />
  <Display Level="Full" AcceptEULA="TRUE" />
  <Property Name="AUTOACTIVATE" Value="0" />
</Configuration>
```

| Setting | Why |
|---|---|
| `O365ProPlusRetail` | Microsoft 365 Apps for enterprise, which most **school and work** licenses use. A personal or family subscription would use `O365HomePremRetail`. |
| `Channel="Current"` | The same channel the normal installer uses |
| Two `Language` entries | English plus Spanish. Change these to your own. |
| `ExcludeApp Groove` / `Lync` | Leaves out the old OneDrive for Business sync app and Skype for Business |
| `Display Level="Full"` | Shows the normal install window so you can watch progress |
| `AUTOACTIVATE=0` | Lets you sign in and activate later. Useful when the sign-in services are having a bad day (foreshadowing, again). |

## Step 3: get the tool and run it

1. Download the ODT **from Microsoft**. The [Office Deployment Tool overview](https://learn.microsoft.com/deployoffice/overview-office-deployment-tool) links to the Download Center.
2. Run it and extract it into the same `Downloads\ODT` folder. You'll get `setup.exe` plus some sample XML files.
3. In an **Administrator** PowerShell:

```powershell
cd "$env:USERPROFILE\Downloads\ODT"
.\setup.exe /configure configuration.xml
```

## "It just closed, I didn't get to see what happened"

The ODT window appeared and vanished within seconds. I assumed it was another L. Back to the logs, and a new one had been written:

```text
14:55:38  CabManager::DetermineCabName ... Platform:x64 -> v64.cab
14:56:41  CabManager::Download  http://officecdn.microsoft.com/pr/492350f6-3a01-4f97-b9c0-c7c6ddf67d60 ... v64.cab
14:56:46  ActivityEnded  Office.ClickToRun.DownloadCab2  "Success": true, "Data.SourceProtocol": "cdn"
14:56:46  VersionDescriptor::GetLatestOfficeVersionForOsVersion  "Has AvailableBuilds to parse."
14:56:46  ActivityEnded  Office.ClickToRun.C2RClient.MRO.MroLoadMroDataVCab  "Success": true
14:56:46  MRO::DetermineVersionToUse  ... 'AvailBld':'16.0.20527.20196' ...  "TriggerSource":"ODT"
14:56:46  TransportRetry::ExecuteDownloadFile  "Download succeeded" ... officecdn.microsoft.com ...
15:00:14  ICabDownloader::DownloadAndExtract  "Success..."
```

| Log line | Meaning |
|---|---|
| `DownloadCab2 ... "SourceProtocol": "cdn"` | Got the version catalogue (`v64.cab`) **from the CDN** |
| `Has AvailableBuilds to parse` | The catalogue contained the list of builds |
| `AvailBld: 16.0.20527.20196` | Picked a version **without** the release service |
| `Download succeeded` | Downloaded the installer core |

Then it handed off to Office's own installer, and a moment later this popped up:

```
Microsoft
Please stay online while Microsoft 365 and Office downloads
We'll be done in just a moment.
[■□□□□□□□□□□□□□□□]
```

> **"Forget it, I think it's working!"**

It was. 🎉 The ODT's `setup.exe` closing so fast wasn't a crash. It just hands off to the Click-to-Run service and exits.

## After installing

- Open Word and sign in. With a school or work account, choose **"No, sign in to this app only."**
- Make sure the hosts entry from Chapter 6 is gone (Step 1).

---

## 🧠 Stop and think

1. Why did the ODT succeed when the web installer, Store installer and all my retries failed?
2. The workaround worked, but did I actually know *why* the server wasn't answering?

<details>
<summary><b>Answers</b></summary>

1. It took a **different path** to the same information. The web and Store installers depend on the release service (`mrodevicemgr`). The ODT can read the build list from the CDN's version catalogue. Same goal, different server.
2. **Nope.** I'd only shown it wasn't my PC's fault. The *why* came from somewhere I should have looked first. See [Chapter 8](08-plot-twist.md).

</details>

---

[← Chapter 6](06-network-forensics.md) · [Back to README](../README.md) · [Next: Plot Twist →](08-plot-twist.md)
