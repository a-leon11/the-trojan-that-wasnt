# Chapter 2: What It Really Was

[← Chapter 1](01-the-alert.md) · [Back to README](../README.md) · [Next: The Cleanup →](03-the-cleanup.md)

---

I checked Task Manager, didn't see anything obviously evil, and declared victory:

> "Yeah there's nothing suspicious, just a botched installation."

Narrator: *it was not just a botched installation.*

I wanted the leftover files gone. The places to look: Protection history, Downloads and `%temp%`. Good to know: **deleting the contents of `%temp%` is safe**: the contents, not the folder itself, and skip anything that's in use.

Then Windows refused to delete the download folder:

```
Folder In Use
The action can't be completed because the folder or a file in it is open in another program

Microsoft Office Pro Plus 2021-2024 ... Activator ... (<release group>)
```

## The folder name says it all

The folder name answered Chapter 1's question for me. It wasn't just an unofficial installer; it came **bundled with an "Activator"**, a tool that fakes Office licensing. Those are among the most common carriers for info-stealers, and the `Bearfoos.B!ml` detection fit that pattern exactly.

My call: treat it as real. "In use" can be harmless (an open Explorer window, the preview pane, Defender still scanning), but it can also mean **something from that package is still running**. The plan:

1. Close every Explorer window and the preview pane, then retry.
2. Look in Task Manager for anything named like the installer or activator.
3. Use **Resource Monitor → CPU → Associated Handles** to search for the folder name and see which process holds the lock.
4. If nothing shows up, restart and delete the folder before opening anything else.

## Going to the source

At this point I stopped guessing and went straight to **Windows Security → Protection history** to expand the quarantined entry:

```
Threat quarantined                                   Severe
✔ This threat or app has been allowed and will not be remediated in the future.

Alert level:  Severe
Status:       Quarantined
Category:     Trojan
Details:      This program is dangerous and executes commands from an attacker.

Affected items:
file: C:\Users\<user>\AppData\Local\Temp\is-XXXXXXXXXX.tmp\MJ548\0000_Setup.exe
```

Two lines in there were very much not the vibe:

- **"This program is dangerous and executes commands from an attacker."** That isn't adware. It describes **backdoor behaviour**.
- **"This threat or app has been allowed."** At some point I had clicked **Allow on device**. So the file may actually have run. Oops. 💀

I chose **Actions → Remove** and dropped my earlier "I'm probably fine" take. With an *allowed* backdoor-type detection, the PC had to be treated as **possibly compromised**:

1. **Change passwords now, from your phone**, starting with email and the Microsoft account, then banking, school and social accounts.
2. **Sign out of all sessions** and turn on **two-factor authentication**.
3. Run a **Microsoft Defender Offline scan**, then a full scan.
4. Turn on **Potentially unwanted app blocking**, which Windows Security showed as off.
5. If the offline scan finds more, or there are logins you don't recognise, **reset Windows**.

The threat was deleted. Lesson learned: unofficial = untrusted, no matter how convincing the download page looks.

---

## 🧠 Stop and think

1. Why is "allowed" so much worse than "quarantined"?
2. Why change passwords from a **different device**?
3. I now plan to install Office the legit way. What could go wrong?

<details>
<summary><b>Answers</b></summary>

1. Quarantine means the file was stopped before or as it ran. "Allowed" means Defender was told to **let it run and not touch it again**. From that moment you can't assume it didn't execute.
2. If an info-stealer or keylogger is still active, typing a new password on the infected PC just hands it over again.
3. Nothing *should*. But keep this question in mind, because the answer to "why won't Office install now?" is going to look *very* connected to this trojan. Spoiler: it wasn't.

</details>

---

[← Chapter 1](01-the-alert.md) · [Back to README](../README.md) · [Next: The Cleanup →](03-the-cleanup.md)
