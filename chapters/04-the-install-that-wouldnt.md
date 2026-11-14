# Chapter 4: The Install That Wouldn't

[← Chapter 3](03-the-cleanup.md) · [Back to README](../README.md) · [Next: Reading the Logs →](05-reading-the-logs.md)

---

PC cleaned up, I finally did the right thing: downloaded the **official** installer (`OfficeSetup.exe`) from office.com, to sign in with my school Microsoft 365 account. Character development.

> 💡 **Side note on school and work accounts:** when Office asks *"Allow my organization to manage my device?"*, choose **"No, sign in to this app only."** The account stays inside Office and your PC doesn't get enrolled in the organisation's device management.

And then:

```
Couldn't install

We're sorry, we had a problem installing your Microsoft 365 and Office program(s).

Is your internet connection working?  Do you have enough free space on your
main hard drive?

Please try installing again after you've checked the above.

Error Code: 0-2015 (2250)
```

My exact reaction, preserved for history:

> **"What the f\*\*\*."**

## The obvious theory

My first thought: **the activator broke something.** Office activators are known to:

- leave behind Office registry keys and Click-to-Run components,
- add **hosts file** entries that block Microsoft's licensing servers,
- add **firewall rules** that cut Office off from the internet,
- install KMS emulators and scheduled tasks.

So the plan was to undo all of that. Seemed airtight. It was not.

## Round 1: the usual fixes

| Tried | Why | Result |
|---|---|---|
| Restart and retry | The classic | ❌ Same error |
| Check Installed apps for leftover Office / KMS / activator entries | A partial install blocks a new one | Nothing there |
| Check free disk space | The error message itself suggests it | ~87 GB free |
| Check the internet connection | The error message suggests that too | Wi-Fi connected |
| Uninstall the **Copilot** app | I wondered if it conflicted | ❌ Same error (it doesn't conflict, RIP Copilot) |
| Install from the **Microsoft Store** instead | Different install path | Froze at the same point |
| Look up the error code | 0-2015 (2250) | Suggestions: Smart App Control, a leftover `Office` registry key under `HKLM\SOFTWARE\WOW6432Node`, Microsoft's uninstall tool, the offline installer |

## Round 2: going deeper

Some things went better than expected, some worse:

| Step | What happened |
|---|---|
| **hosts file** | Opened in Notepad and checked line by line. **Clean**, just the Windows default. No activator blocks. |
| **Smart App Control** | Windows Security → App & browser control. **Already off.** (Careful: once you turn it off, you can't turn it back on without resetting Windows.) |
| **Defender** | Protection history: **no new blocks** since the trojan. Defender wasn't stopping the official installer. |
| **Microsoft Support and Recovery Assistant** | Found on my desktop, but it only showed a message saying it's been retired in favour of the **Get Help** app. |
| **Get Help** | Opened **completely blank**. Thanks, I guess. |
| **Registry Editor, Task Manager, Task Scheduler** | My remote-control tool could *see* them but **couldn't click in them**. |

### Why remote control couldn't click in some apps

Registry Editor, Task Manager and Task Scheduler (`mmc.exe`) run **as administrator**. Windows' **User Interface Privilege Isolation (UIPI)** blocks a normal-level process from sending clicks and keystrokes into an elevated window. Remote-control and automation tools hit the same wall. It's a security feature, not a bug. From here on, anything that needed admin rights was done directly at the keyboard.

## Still failing

By now:

- the trojan was gone,
- the hosts file was clean,
- no leftovers were installed,
- Smart App Control and Defender weren't involved,
- the Store install was frozen.

And still `0-2015 (2250)`. Twenty minutes into the Store install, my mood was:

> "Still cannot f\*\*\*ing install, it's been 20 minutes already."

Peak frustration. We've all been there.

---

## 🧠 Stop and think

1. Up to this point, every step tried a **fix**. What hadn't been done yet?
2. The error message asks *"Is your internet connection working?"*. Should you take that literally?

<details>
<summary><b>Answers</b></summary>

1. I hadn't looked at **what the installer itself recorded** about the failure. Installers almost always write logs. Reading them is diagnosis; everything before was guessing.
2. **Yes, though not the way it suggests.** My general internet worked fine. But "can't reach *one specific* server" produces the same generic message. The useful question isn't "is the internet working?" but "which connection failed?" Chapter 5 answers that.

</details>

---

[← Chapter 3](03-the-cleanup.md) · [Back to README](../README.md) · [Next: Reading the Logs →](05-reading-the-logs.md)
