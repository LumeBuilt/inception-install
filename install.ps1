# Inception harness: the setup doc's one command for Windows (PowerShell). It downloads the harness into your user
# folder and gets the free tools it needs; /setup (in the Claude app) does everything after that. Safe to run again:
# it carries on where it stopped and never deletes anything.
#
#   powershell -ExecutionPolicy ByPass -c "irm <where AA publishes it>/install.ps1 | iex"
#
# It needs, and gets if missing (with Windows' own winget): Git for Windows (git, Git Bash, and Git Credential
# Manager, which signs you in to GitHub in your web browser: the harness's repository is private), Python 3, and uv
# (Astral's free Python runner, astral.sh). Nothing here asks for or stores a password.
# Tests set INCEPTION_REPO (a local copy) and INCEPTION_DIR; nobody else needs them.
# NOTE: not yet run on a real Windows computer (the harness's Windows support is tested with fakes only).

$ErrorActionPreference = "Continue"
$Repo = if ($env:INCEPTION_REPO) { $env:INCEPTION_REPO } else { "https://github.com/LumeBuilt/inception-harness.git" }
$Dir = if ($env:INCEPTION_DIR) { $env:INCEPTION_DIR } else { Join-Path $env:USERPROFILE "Inception" }

function Say($m) { Write-Host $m }
function Fail($m) { Write-Host ""; Write-Host "STOPPED: $m"; exit 1 }
function Refresh-Path {
  $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User") + ";" + (Join-Path $env:USERPROFILE ".local\bin")
}
function Have($name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }
function Winget-Install($id, $what) {
  if (-not (Have "winget")) { Fail "$what is missing and this computer has no winget to get it. Install $what yourself (see the setup doc), then paste the same command again." }
  Say "Getting $what (Windows may ask you to allow it)..."
  winget install --id $id -e --source winget --accept-package-agreements --accept-source-agreements --silent | Out-Null
  Refresh-Path
}

Say "Inception harness: getting it onto this computer."

# 0. Already here?
foreach ($d in @($Dir, (Join-Path $Dir "harness"))) {
  if ((Test-Path (Join-Path $d "ops\setup.py")) -and (Test-Path (Join-Path $Dir ".git"))) {
    Say ""; Say "The harness is already on this computer, in: $d"
    Say "Next: open the Claude app, click Code, choose that folder, and type /setup"
    exit 0
  }
}
if ((Test-Path $Dir) -and (Get-ChildItem -Force $Dir | Select-Object -First 1)) {
  Fail "a folder named $(Split-Path $Dir -Leaf) already exists in your user folder and isn't the harness. Rename or move it, then paste the same command again."
}

# 1. Git for Windows (git, Git Bash for the harness's checks, and the browser sign-in to GitHub)
if (-not (Have "git")) { Winget-Install "Git.Git" "Git for Windows" }
if (-not (Have "git")) { Fail "Git for Windows didn't install. Get it from git-scm.com (all the default choices), then paste the same command again." }
if (-not (Test-Path "C:\Program Files\Git\bin\bash.exe") -and -not $env:CLAUDE_CODE_GIT_BASH_PATH) {
  Fail "Git Bash wasn't found (it comes with Git for Windows from git-scm.com). Install it with the default choices, then paste the same command again."
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
if (-not $py) { Fail "Python didn't install. Get it from python.org (tick 'Add python.exe to PATH' and keep 'tcl/tk and IDLE'), then open a new PowerShell window and paste the same command again." }

# 3. uv
Refresh-Path
if (-not (Have "uv")) {
  Say "Getting uv (a free tool that runs the harness's scripts)..."
  try { Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression | Out-Null } catch { }
  Refresh-Path
  if (-not (Have "uv")) { Fail "couldn't get uv (it needs the internet). Check the connection, then paste the same command again." }
}

# 4. Download (Git Credential Manager opens your web browser to sign in to GitHub the first time)
Say "Downloading the harness into $Dir (if your browser opens GitHub, sign in and approve)..."
git clone --quiet $Repo $Dir
if ($LASTEXITCODE -ne 0) { Fail "the download didn't finish. If GitHub said you don't have access, ask AA to give your GitHub account access; otherwise check the internet connection. Then paste the same command again." }
$Open = $Dir
if (-not (Test-Path (Join-Path $Dir "ops\setup.py"))) { $Open = Join-Path $Dir "harness" }
if (-not (Test-Path (Join-Path $Open "ops\setup.py"))) { Fail "what was downloaded isn't the harness. Tell AA." }

Say ""
Say "Done: the harness is in $Open"
Say "Next:"
Say "  1. Open the Claude app (download it from claude.ai/download if you don't have it) and sign in. If it was"
Say "     already open, quit it and open it again, so it finds the tools this just added."
Say "  2. Click Code, then choose the folder: $Open"
Say "  3. Type /setup and press Enter. Claude guides you from there."
