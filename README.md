# Inception installer

The one-command download for the Inception harness. These two files only download the harness: they get the free
tools it needs and sign you in to GitHub in your browser. The harness itself is in a private repository; your GitHub
account needs access to it.

- Mac: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/LumeBuilt/inception-install/main/install.sh)"`
- Windows (PowerShell): `powershell -ExecutionPolicy ByPass -c "irm https://raw.githubusercontent.com/LumeBuilt/inception-install/main/install.ps1 | iex"`

Then open the downloaded Inception folder in the Claude app (Code) and type `/setup`.
Status: testing. The Windows installer hasn't been run on a real Windows computer yet.
