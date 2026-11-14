# Chapter 3: The Cleanup

[← Chapter 2](02-what-it-really-was.md) · [Back to README](../README.md) · [Next: The Install That Wouldn't →](04-the-install-that-wouldnt.md)

---

With the threat removed, the next question was: **is anything else still lurking?** This chapter is the sweep. It's worth a read even if you'd never touch an unofficial installer, because it shows where Windows malware usually hides and how to tell a scary-looking file from a harmless one.

## Where I looked

| Place | How | Result |
|---|---|---|
| Protection history | Windows Security | Threat removed; no new detections afterwards |
| The download folder | File Explorer | Deleted; only a dead **Quick access pin** left behind (unpinned later) |
| `%TEMP%` | Emptied it | Installer leftovers gone |
| Per-user Startup folder | `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup` | One expected app |
| All-users Startup folder | `%PROGRAMDATA%\Microsoft\Windows\Start Menu\Programs\StartUp` | Empty |
| `%APPDATA%`, `%LOCALAPPDATA%`, `%PROGRAMDATA%` | Browsed and listed | No random-named or unknown folders |
| `Program Files`, `Program Files (x86)` | Browsed | No leftover Office or activator folders |
| Installed apps | Settings → Apps → search `office`, `365`, `kms`, `activ` | Nothing found |
| Task Manager | A screen recording of every tab | Only Windows, hardware drivers and my own apps |

### A trick for hidden folders

`AppData` is hidden in File Explorer by default. Quick trick: open **Notepad's File → Open dialog**, type a path like `%LOCALAPPDATA%\Temp`, and set the filter to **All files (\*.\*)**. Big brain move. It's a handy way to browse hidden system folders without changing Explorer settings.

### Reviewing Task Manager from a video

Instead of a dozen screenshots, I recorded a short video scrolling through Task Manager and pulled frames out of it with `ffmpeg`:

```bash
# one frame every second
ffmpeg -i recording.mp4 -vf "fps=1,scale=1456:-1" frames/g_%02d.png
```

Then I stitched them into contact sheets and went through every tab: Processes, Startup apps, Details and Services. Verdict: **nothing suspicious**. A process list only shows what's running *now*, though. A one-shot stealer that ran hours earlier wouldn't be in it, which is why the password advice still stood.

## The scary process that wasn't

During the sweep, a process with a **random 8-character name** turned up, running from a GUID-named temp folder:

```
C:\Users\<user>\AppData\Local\Temp\94f9fa8f05c04f4cacc04412e418e5f8\y4pqzbew.exe
```

A random name in `%TEMP%` is exactly what malware looks like. My heart rate agreed. Instead of killing it, I checked the file's properties first:

```
File description: Microsoft 365 and Office
Company:          Microsoft Corporation
File version:     16.0.20527.20196
Size:             6.93 MB
```

A **`WinGet`** folder had been created in `%TEMP%` at the same minute. I'd just started installing Office **from the Microsoft Store**, and the Store downloads desktop installers through WinGet and runs them under random names. It was **Microsoft's own installer**. False alarm. 😅

> 💡 **Lesson:** check the signature and publisher before you kill or delete anything. In File Explorer: right-click → Properties → **Digital Signatures**.

## Not malware, but worth knowing

- **I'd installed a disk-image mounting tool the same day.** Free versions of some of these bundle adware offers. Not malicious, but if you only need to open an `.iso`, Windows can mount it natively (just double-click it).
- **I'd run a "debloat" script a few days earlier.** These scripts remove built-in Microsoft components. That may explain why Microsoft's **Get Help** app later opened completely blank.

---

## 🧠 Stop and think

1. The sweep came back clean. Does that prove the trojan never ran?
2. If you found an unknown `.exe` running from `%TEMP%`, what three things would you check before deleting it?

<details>
<summary><b>Answers</b></summary>

1. **No.** It shows there's no *persistence*: nothing set to start again and nothing running. A stealer that ran once, uploaded its loot and exited would leave this exact picture. Hence: change passwords and run an offline scan anyway.
2. (a) Its **digital signature and publisher** in Properties; (b) **what created it**, meaning the parent process and what else changed in `%TEMP%` at the same time (here, a `WinGet` folder); (c) its **hash on VirusTotal**. Deleting a running file usually fails anyway, and killing a legitimate installer just makes a mess.

</details>

---

[← Chapter 2](02-what-it-really-was.md) · [Back to README](../README.md) · [Next: The Install That Wouldn't →](04-the-install-that-wouldnt.md)
