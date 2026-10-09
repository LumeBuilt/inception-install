#!/bin/bash
# Inception harness: the setup doc's one command for a Mac. It downloads the harness into your home folder and gets
# the free tools it needs; /setup (in the Claude app) does everything after that. Safe to run again: it carries on
# where it stopped and never deletes anything.
#
#   /bin/bash -c "$(curl -fsSL <where AA publishes it>/install.sh)"
#
# It needs, and gets if missing: Apple's free command line tools (git and Python, Apple's own installer window),
# uv (Astral's free Python runner, astral.sh), and a GitHub sign-in (GitHub's own `gh` tool, signed in through your
# web browser) because the harness's repository is private. Nothing here asks for or stores a password.
# Tests set INCEPTION_REPO (a local copy) and INCEPTION_DIR; nobody else needs them.
set -u
REPO="${INCEPTION_REPO:-https://github.com/LumeBuilt/inception-harness.git}"
DIR="${INCEPTION_DIR:-$HOME/Inception}"
BIN="$HOME/.local/bin"

say() { printf '%s\n' "$*"; }
fail() { printf '\nSTOPPED: %s\n' "$*"; exit 1; }

say "Inception harness: getting it onto this computer."
[ "$(uname -s)" = "Darwin" ] || fail "this command is for a Mac. On Windows, use the Windows command in the setup doc."

# 0. Already here?
for d in "$DIR" "$DIR/harness"; do
  if [ -f "$d/ops/setup.py" ] && [ -d "$DIR/.git" ]; then
    say ""
    say "The harness is already on this computer, in: $d"
    say "Next: open the Claude app, click Code, choose that folder, and type /setup"
    exit 0
  fi
done
if [ -e "$DIR" ] && [ -n "$(ls -A "$DIR" 2>/dev/null)" ]; then
  fail "a folder named $(basename "$DIR") already exists in your home folder and isn't the harness. Rename or move it, then paste the same command again."
fi

# 1. Apple's command line tools (git and Python come with them)
if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install >/dev/null 2>&1
  fail "your Mac needs Apple's free command line tools first. A window has opened: click Install and wait until it says it's done (5 to 15 minutes). Then paste the same command again."
fi
command -v git >/dev/null 2>&1 && git --version >/dev/null 2>&1 \
  || fail "git isn't working yet. If Apple's installer is still running, wait for it to finish; then paste the same command again."
/usr/bin/python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)' >/dev/null 2>&1 \
  || fail "Python 3.9 or newer isn't working yet (it comes with Apple's command line tools). Wait for that installer to finish, then paste the same command again."

# 2. uv
UV="$(command -v uv 2>/dev/null || true)"
[ -z "$UV" ] && [ -x "$BIN/uv" ] && UV="$BIN/uv"
if [ -z "$UV" ]; then
  say "Getting uv (a free tool that runs the harness's scripts)..."
  curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1 || true
  [ -x "$BIN/uv" ] && UV="$BIN/uv"
  [ -n "$UV" ] || fail "couldn't get uv (it needs the internet). Check the connection, then paste the same command again."
fi

# 3. Access to the private repository: a GitHub sign-in through the web browser, once
can_read() { GIT_TERMINAL_PROMPT=0 git ls-remote "$REPO" HEAD >/dev/null 2>&1; }
if ! can_read; then
  GH="$(command -v gh 2>/dev/null || true)"
  [ -z "$GH" ] && [ -x "$BIN/gh" ] && GH="$BIN/gh"
  if [ -z "$GH" ]; then
    say "Getting GitHub's sign-in tool (gh, from GitHub)..."
    case "$(uname -m)" in arm64) ARCH=arm64 ;; *) ARCH=amd64 ;; esac
    URL="$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest 2>/dev/null \
           | grep -o "https://[^\"]*_macOS_${ARCH}\.zip" | head -n 1)"
    TMP="$(mktemp -d)"
    if [ -n "$URL" ] && curl -fsSL "$URL" -o "$TMP/gh.zip" 2>/dev/null && unzip -q "$TMP/gh.zip" -d "$TMP" 2>/dev/null; then
      mkdir -p "$BIN" && cp "$(find "$TMP" -path '*/bin/gh' -type f | head -n 1)" "$BIN/gh" 2>/dev/null && chmod +x "$BIN/gh" && GH="$BIN/gh"
    fi
    rm -rf "$TMP"
    [ -n "$GH" ] || fail "couldn't get GitHub's sign-in tool (it needs the internet). Check the connection, then paste the same command again."
  fi
  if ! "$GH" auth status >/dev/null 2>&1; then
    say ""
    say "Sign in to GitHub (once). Below, GitHub's tool shows a one-time code: copy it, press Enter, and your web"
    say "browser opens GitHub; sign in, paste the code, and approve. If it asks a question, press Enter."
    say ""
    "$GH" auth login --hostname github.com --git-protocol https --web || fail "the GitHub sign-in didn't finish. Paste the same command again to try again."
  fi
  "$GH" auth setup-git --hostname github.com >/dev/null 2>&1
  can_read || fail "your GitHub account can't see the harness yet. Ask AA to give your GitHub account access, then paste the same command again."
fi

# 4. Download
say "Downloading the harness into $DIR ..."
GIT_TERMINAL_PROMPT=0 git clone --quiet "$REPO" "$DIR" || fail "the download didn't finish (check the internet connection), then paste the same command again."
OPEN="$DIR"
[ -f "$DIR/ops/setup.py" ] || OPEN="$DIR/harness"
[ -f "$OPEN/ops/setup.py" ] || fail "what was downloaded isn't the harness. Tell AA."

say ""
say "Done: the harness is in $OPEN"
say "Next:"
say "  1. Open the Claude app (download it from claude.ai/download if you don't have it) and sign in. If it was"
say "     already open, quit it and open it again, so it finds the tools this just added."
say "  2. Click Code, then choose the folder: $OPEN"
say "  3. Type /setup and press Enter. Claude guides you from there."
