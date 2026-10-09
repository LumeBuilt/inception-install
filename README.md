# Inception: install instructions

Copy everything in the box below (the copy button is at its top right), paste it into Claude in your new, empty
Inception folder, and press Enter. Claude installs the harness there and tells you when you need to do something.

```text
Install the Inception harness into this folder (the folder this conversation is open in, nowhere else). I'm not technical: whenever I need to do something, tell me in short, plain words, then wait for me.

1. Run this one command, from this folder, with a 10-minute timeout.
   On a Mac:
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/LumeBuilt/inception-install/main/install.sh)" inception --here
   On Windows, instead:
   powershell -NoProfile -ExecutionPolicy Bypass -Command '$env:INCEPTION_HERE=1; irm https://raw.githubusercontent.com/LumeBuilt/inception-install/main/install.ps1 | iex'
2. If it ends with WAITING or STOPPED, tell me exactly what it asks me to do. If it shows a GITHUB CODE, put the code on its own line in bold. Then wait. When I say I've done it, run the same command again. Repeat until it prints DONE.
3. When it prints DONE, tell me its NEXT line, and stop there.

Only run that command: don't download, install, change or fix anything another way, and don't switch folders. Never ask me for a password or a key in this chat (the one-time GitHub code on the screen is fine). If it fails in a way I can't fix, show me its message so I can send it to AA.
```

What you'll see while it runs:

- **Claude asks to allow a command**: click Allow (it's the installer above).
- **Mac, the first time:** Apple's window to install its free "command line tools" may open: click Install, wait
  until it's done (5 to 15 minutes), then tell Claude "done".
- **GitHub sign-in (once per computer):** your web browser opens GitHub and Claude shows you a one-time code.
  Sign in to GitHub, paste the code, click Continue, then Authorize, and tell Claude "done". Your GitHub account
  needs access to the harness: AA gives it.
- **At the end** Claude says: start a new conversation in this folder (the **+** button) and type `/setup`.

**Windows:** the same box works. Windows may ask to allow installing Git, Python or uv; say yes. GitHub's sign-in
opens in your browser on its own (no code): sign in and approve. (The Windows installer hasn't been run on a real
Windows computer yet.)

---

These two files only download the harness: they get the free tools it needs and sign you in to GitHub. The harness
itself is in a private repository. Without the Claude app, from Terminal (Mac) or PowerShell (Windows), the same
installers download it into a folder called Inception in your home folder:

- Mac: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/LumeBuilt/inception-install/main/install.sh)"`
- Windows: `powershell -ExecutionPolicy ByPass -c "irm https://raw.githubusercontent.com/LumeBuilt/inception-install/main/install.ps1 | iex"`

Then open that Inception folder in the Claude app (Code) and type `/setup`.
