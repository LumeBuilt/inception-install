# Inception harness: the Windows installer (PowerShell). It downloads the harness and gets the free tools it needs;
# /setup (in the Claude app) does everything after that. Safe to run again: it carries on where it stopped and never
# deletes anything.
#
# Two ways to run it:
#   - From the Claude app (the setup doc's way): the partner pastes the install instructions from
#     github.com/LumeBuilt/inception-install into Claude, in a new empty folder, and Claude runs
#       powershell -NoProfile -ExecutionPolicy Bypass -Command '$env:INCEPTION_HERE=1; irm https://raw.githubusercontent.com/LumeBuilt/inception-install/main/install.ps1 | iex'
#     INCEPTION_HERE: download into the current folder (empty, or only what Windows or Claude put in a new folder),
#     then write this folder's safety checks (the first /setup step); the partner starts a new conversation and types /setup.
#   - From PowerShell (the fallback): powershell -ExecutionPolicy ByPass -c "irm <same address> | iex" downloads into
#     your user folder's Inception.
#
# It needs, and gets if missing (with Windows' own winget): Git for Windows (git, Git Bash, and Git Credential
# Manager, which signs you in to GitHub in your web browser: the harness's repository is private), Python 3, and uv
# (Astral's free Python runner, astral.sh). Nothing here asks for or stores a password.
# The last lines are DONE / NEXT when it has finished, or STOPPED: <what to do> when it needs the partner.
# Tests set INCEPTION_REPO (a local copy) and INCEPTION_DIR; nobody else needs them.
# NOTE: not yet run on a real Windows computer (the harness's Windows support is tested with fakes only).

$ErrorActionPreference = "Continue"
$Repo = if ($env:INCEPTION_REPO) { $env:INCEPTION_REPO } else { "https://github.com/LumeBuilt/inception-harness.git" }
$Here = [bool]$env:INCEPTION_HERE
$Dir = if ($env:INCEPTION_DIR) { $env:INCEPTION_DIR } elseif ($Here) { (Get-Location).Path } else { Join-Path $env:USERPROFILE "Inception" }
$Again = if ($Here) { "say so in the chat, and Claude runs the same command again" } else { "paste the same command again" }

function Say($m) { Write-Host $m }
function Fail($m) { Write-Host ""; Write-Host "STOPPED: $m"; exit 1 }
function Refresh-Path {
  $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User") + ";" + (Join-Path $env:USERPROFILE ".local\bin")
}
function Have($name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }
function Winget-Install($id, $what) {
  if (-not (Have "winget")) { Fail "$what is missing and this computer has no winget to get it. Install $what yourself (see the setup doc), then $Again." }
  Say "Getting $what (Windows may ask you to allow it)..."
  winget install --id $id -e --source winget --accept-package-agreements --accept-source-agreements --silent | Out-Null
  Refresh-Path
}

Say "Inception harness: getting it onto this computer."

# 0. Already here? Is the folder free?
$Open = $null
foreach ($d in @($Dir, (Join-Path $Dir "harness"))) {
  if (-not $Open -and (Test-Path (Join-Path $d "ops\setup.py")) -and (Test-Path (Join-Path $Dir ".git"))) { $Open = $d }
}
if ($Open -and -not $Here) {
  Say ""; Say "The harness is already on this computer, in: $Open"
  Say "Next: open the Claude app, click Code, choose that folder, and type /setup"
  exit 0
}
function Only-New-Folder-Files($p) {
  # empty, or only what Windows (Explorer) or Claude Code put in a new folder
  foreach ($f in Get-ChildItem -Force $p) {
    if (@("desktop.ini", "Thumbs.db", ".DS_Store") -contains $f.Name) { continue }
    if ($f.Name -eq ".claude" -and $f.PSIsContainer) {
      foreach ($g in Get-ChildItem -Force $f.FullName) { if (@("settings.local.json", "desktop.ini") -notcontains $g.Name) { return $false } }
      continue
    }
    return $false
  }
  return $true
}
if (-not $Open -and (Test-Path $Dir)) {
  if ($Here) {
    if (-not (Only-New-Folder-Files $Dir)) { Fail "this folder ($Dir) isn't empty, and the harness goes into an empty folder. Make a new empty folder (for example one named Inception in your user folder), open it in the Claude app (Code), and paste the install instructions there." }
  } elseif (Get-ChildItem -Force $Dir | Select-Object -First 1) {
    Fail "a folder named $(Split-Path $Dir -Leaf) already exists in your user folder and isn't the harness. Rename or move it, then $Again."
  }
}

# 1. Git for Windows (git, Git Bash for the harness's checks, and the browser sign-in to GitHub)
if (-not (Have "git")) { Winget-Install "Git.Git" "Git for Windows" }
if (-not (Have "git")) { Fail "Git for Windows didn't install. Get it from git-scm.com (all the default choices), then $Again." }
if (-not (Test-Path "C:\Program Files\Git\bin\bash.exe") -and -not $env:CLAUDE_CODE_GIT_BASH_PATH) {
  Fail "Git Bash wasn't found (it comes with Git for Windows from git-scm.com). Install it with the default choices, then $Again."
}

# 2. Python 3 (the real one, not the Microsoft Store shortcut)
$py = $null
foreach ($c in @("py", "python")) {
  if (Have $c) {
    $v = & $c -c "import sys; print(sys.version_info >= (3, 9))" 2>$null
    if ($v -eq "True") { $py = $c; break }
  }
}
if (-not $py) { Winget-Install "Python.Python.3.12" "Python 3"; if (Have "py") { $py = "py" } }
if (-not $py) { Fail "Python didn't install. Get it from python.org (tick 'Add python.exe to PATH' and keep 'tcl/tk and IDLE'), then $Again." }

# 3. uv
Refresh-Path
if (-not (Have "uv")) {
  Say "Getting uv (a free tool that runs the harness's scripts)..."
  try { Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression | Out-Null } catch { }
  Refresh-Path
  if (-not (Have "uv")) { Fail "couldn't get uv (it needs the internet). Check the connection, then $Again." }
}

# 4. Download (Git Credential Manager opens your web browser to sign in to GitHub the first time; the download waits
#    until you've signed in and approved)
if (-not $Open) {
  Say "Downloading the harness into $Dir (if your browser opens GitHub, sign in and approve)..."
  if ($Here -and (Test-Path $Dir)) {
    # git won't download into a folder that has anything in it, so it downloads beside it and moves its record (.git) in
    $Tmp = Join-Path ([IO.Path]::GetTempPath()) ("inception-" + [guid]::NewGuid().ToString("N"))
    git clone --quiet --no-checkout $Repo (Join-Path $Tmp "h")
    $ok = ($LASTEXITCODE -eq 0)
    if ($ok) { Move-Item -Force (Join-Path $Tmp "h\.git") (Join-Path $Dir ".git"); git -C $Dir reset --quiet --hard HEAD; $ok = ($LASTEXITCODE -eq 0) }
    Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
  } else {
    git clone --quiet $Repo $Dir
    $ok = ($LASTEXITCODE -eq 0)
  }
  if (-not $ok) { Fail "the download didn't finish. If GitHub said you don't have access, ask AA to give your GitHub account access; otherwise check the internet connection. Then $Again." }
  $Open = $Dir
  if (-not (Test-Path (Join-Path $Dir "ops\setup.py"))) { $Open = Join-Path $Dir "harness" }
  if (-not (Test-Path (Join-Path $Open "ops\setup.py"))) { Fail "what was downloaded isn't the harness. Tell AA." }
  Say "Downloaded: the harness is in $Open"
}

if ($Here) {
  # 5. The first /setup step: this folder's safety checks (they load when a new conversation starts)
  Say ""; Say "Writing this computer's safety checks for this folder..."
  $env:UV_PYTHON_DOWNLOADS = "never"
  Push-Location $Open
  uv run --quiet ops/setup.py --from-install
  $ok = ($LASTEXITCODE -eq 0)
  Pop-Location
  Say ""
  Say $(if ($ok) { "DONE" } else { "DONE (the safety checks will be finished by /setup)" })
  Say "NEXT: start a new conversation in this folder (the + button) and type /setup"
  exit 0
}

Say ""
Say "Done: the harness is in $Open"
Say "Next:"
Say "  1. Open the Claude app (download it from claude.ai/download if you don't have it) and sign in. If it was"
Say "     already open, quit it and open it again, so it finds the tools this just added."
Say "  2. Click Code, then choose the folder: $Open"
Say "  3. Type /setup and press Enter. Claude guides you from there."
