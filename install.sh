#!/bin/bash
# Inception harness: the Mac installer. It downloads the harness and gets the free tools it needs; /setup (in the
# Claude app) does everything after that. Safe to run again: it carries on where it stopped and never deletes anything.
#
# Two ways to run it:
#   - From the Claude app (the setup doc's way): the partner pastes the install instructions from
#     github.com/LumeBuilt/inception-install into Claude, in a new empty folder, and Claude runs
#       /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/LumeBuilt/inception-install/main/install.sh)" inception --here
#     --here: download into the current folder (empty, or only what the Mac or Claude put in a new folder), then write
#     this folder's safety checks (the first /setup step), so the partner only starts a new conversation and types /setup.
#   - From Terminal (the fallback): the same line without `inception --here` downloads into ~/Inception.
#
# It needs, and gets if missing: Apple's free command line tools (git and Python, Apple's own installer window),
# uv (Astral's free Python runner, astral.sh), and a GitHub sign-in (GitHub's own `gh` tool, signed in through your
# web browser with a one-time code) because the harness's repository is private. Nothing here asks for or stores a
# password. When it needs the partner (Apple's window, the GitHub code) it says so and stops, or prints WAITING; running
# the same line again carries on. The last line is DONE / NEXT when it has finished.
# Tests set INCEPTION_REPO (a local copy), INCEPTION_DIR and INCEPTION_STATE; nobody else needs them.
set -u
REPO="${INCEPTION_REPO:-https://github.com/LumeBuilt/inception-harness.git}"
HERE="${INCEPTION_HERE:-}"
for a in "$@"; do [ "$a" = "--here" ] && HERE=1; done
if [ -n "$HERE" ]; then DIR="${INCEPTION_DIR:-$PWD}"; else DIR="${INCEPTION_DIR:-$HOME/Inception}"; fi
BIN="$HOME/.local/bin"
STATE="${INCEPTION_STATE:-$HOME/.local/state/inception-install}"     # the GitHub sign-in's progress (never a key)
AGAIN="paste the same command again"
[ -n "$HERE" ] && AGAIN="say so in the chat, and Claude runs the same command again"

say() { printf '%s\n' "$*"; }
fail() { printf '\nSTOPPED: %s\n' "$*"; exit 1; }

say "Inception harness: getting it onto this computer."
[ "$(uname -s)" = "Darwin" ] || fail "this command is for a Mac. On Windows, use the Windows command in the install instructions."

# 0. Already here? Is the folder free?
OPEN=""
for d in "$DIR" "$DIR/harness"; do
  [ -z "$OPEN" ] && [ -f "$d/ops/setup.py" ] && [ -d "$DIR/.git" ] && OPEN="$d"
done
only_new_folder_files() {   # empty, or only what the Mac (Finder) or Claude Code put in a new folder
  local f g
  for f in "$1"/* "$1"/.[!.]* "$1"/..?*; do
    [ -e "$f" ] || [ -L "$f" ] || continue
    case "${f##*/}" in
      .DS_Store|.localized|Icon$'\r') ;;
      .claude)
        [ -d "$f" ] && [ ! -L "$f" ] || return 1
        for g in "$f"/* "$f"/.[!.]* "$f"/..?*; do
          [ -e "$g" ] || [ -L "$g" ] || continue
          case "${g##*/}" in settings.local.json|.DS_Store) ;; *) return 1 ;; esac
        done ;;
      *) return 1 ;;
    esac
  done
  return 0
}
if [ -n "$OPEN" ] && [ -z "$HERE" ]; then
  say ""
  say "The harness is already on this computer, in: $OPEN"
  say "Next: open the Claude app, click Code, choose that folder, and type /setup"
  exit 0
fi
if [ -z "$OPEN" ] && [ -e "$DIR" ]; then
  if [ -n "$HERE" ]; then
    only_new_folder_files "$DIR" || fail "this folder ($DIR) isn't empty, and the harness goes into an empty folder. Make a new empty folder (for example one named Inception in your home folder), open it in the Claude app (Code), and paste the install instructions there."
  elif [ -n "$(ls -A "$DIR" 2>/dev/null)" ]; then
    fail "a folder named $(basename "$DIR") already exists in your home folder and isn't the harness. Rename or move it, then $AGAIN."
  fi
fi

if [ -z "$OPEN" ]; then
  # 1. Apple's command line tools (git and Python come with them)
  if ! xcode-select -p >/dev/null 2>&1; then
    xcode-select --install >/dev/null 2>&1
    fail "your Mac needs Apple's free command line tools first. A window has opened (it may be behind other windows): click Install, agree, and wait until it says it's done (5 to 15 minutes). Then $AGAIN."
  fi
  command -v git >/dev/null 2>&1 && git --version >/dev/null 2>&1 \
    || fail "git isn't working yet. If Apple's installer is still running, wait for it to finish; then $AGAIN."
  /usr/bin/python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)' >/dev/null 2>&1 \
    || fail "Python 3.9 or newer isn't working yet (it comes with Apple's command line tools). Wait for that installer to finish, then $AGAIN."
fi

# 2. uv
UV="$(command -v uv 2>/dev/null || true)"
[ -z "$UV" ] && [ -x "$BIN/uv" ] && UV="$BIN/uv"
if [ -z "$UV" ]; then
  say "Getting uv (a free tool that runs the harness's scripts)..."
  curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1 || true
  [ -x "$BIN/uv" ] && UV="$BIN/uv"
  [ -n "$UV" ] || fail "couldn't get uv (it needs the internet). Check the connection, then $AGAIN."
fi

if [ -z "$OPEN" ]; then
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
      [ -n "$GH" ] || fail "couldn't get GitHub's sign-in tool (it needs the internet). Check the connection, then $AGAIN."
    fi
    if ! "$GH" auth status --hostname github.com >/dev/null 2>&1; then
      if [ -z "$HERE" ] && [ -t 0 ] && [ -t 1 ]; then
        # Terminal: GitHub's own questions, answered at the keyboard
        say ""
        say "Sign in to GitHub (once). Below, GitHub's tool shows a one-time code: copy it, press Enter, and your web"
        say "browser opens GitHub; sign in, paste the code, and approve. If it asks a question, press Enter."
        say ""
        "$GH" auth login --hostname github.com --git-protocol https --web || fail "the GitHub sign-in didn't finish. Paste the same command again to try again."
      else
        # No keyboard (Claude runs this): gh waits for the browser in the background, and this run hands over the code.
        mkdir -p "$STATE"
        LOG="$STATE/github-signin.log"; PIDF="$STATE/github-signin.pid"
        alive() { [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF" 2>/dev/null)" 2>/dev/null; }
        code_of() { grep -o '[A-Z0-9]\{4\}-[A-Z0-9]\{4\}' "$LOG" 2>/dev/null | head -n 1; }
        if alive; then                          # signed in on the last run's code? gh needs a few seconds to notice
          i=0; while alive && [ $i -lt 30 ]; do sleep 1; i=$((i + 1)); done
        fi
        if ! "$GH" auth status --hostname github.com >/dev/null 2>&1; then
          if ! alive; then                      # first time, or the last code expired (GitHub's codes last 15 minutes)
            rm -f "$LOG"
            nohup "$GH" auth login --hostname github.com --git-protocol https --web </dev/null >"$LOG" 2>&1 &
            echo $! >"$PIDF"
            i=0; while [ -z "$(code_of)" ] && alive && [ $i -lt 40 ]; do sleep 0.5; i=$((i + 1)); done
            [ -n "$(code_of)" ] || fail "GitHub didn't give a sign-in code (check the internet connection), then $AGAIN."
            printf '%s' "$(code_of)" | pbcopy 2>/dev/null
            open "https://github.com/login/device" >/dev/null 2>&1
          fi
          say ""
          say "GITHUB CODE: $(code_of)"
          say ""
          say "WAITING: sign in to GitHub (once). Your web browser has opened github.com/login/device (if not, open that"
          say "address). Sign in to GitHub there, enter the code $(code_of) (it's already copied: just paste it),"
          say "click Continue, then Authorize. Then $AGAIN. The code works for 15 minutes."
          exit 3
        fi
        rm -f "$PIDF" "$LOG"
      fi
    fi
    "$GH" auth setup-git --hostname github.com >/dev/null 2>&1
    can_read || fail "your GitHub account can't see the harness yet. Ask AA to give your GitHub account access, then $AGAIN."
  fi

  # 4. Download
  say "Downloading the harness into $DIR ..."
  if [ -n "$HERE" ] && [ -e "$DIR" ]; then
    # git won't download into a folder that has anything in it (even the Mac's hidden .DS_Store), so it downloads
    # beside it and then moves its record (.git) in; the checks above made sure nothing here has the same name.
    TMP="$(mktemp -d)"
    GIT_TERMINAL_PROMPT=0 git clone --quiet --no-checkout "$REPO" "$TMP/h" \
      && mv "$TMP/h/.git" "$DIR/.git" && git -C "$DIR" reset --quiet --hard HEAD \
      || { rm -rf "$TMP"; fail "the download didn't finish (check the internet connection), then $AGAIN."; }
    rm -rf "$TMP"
  else
    GIT_TERMINAL_PROMPT=0 git clone --quiet "$REPO" "$DIR" || fail "the download didn't finish (check the internet connection), then $AGAIN."
  fi
  OPEN="$DIR"
  [ -f "$DIR/ops/setup.py" ] || OPEN="$DIR/harness"
  [ -f "$OPEN/ops/setup.py" ] || fail "what was downloaded isn't the harness. Tell AA."
  say "Downloaded: the harness is in $OPEN"
fi

if [ -n "$HERE" ]; then
  # 5. The first /setup step: this folder's safety checks (they load when a new conversation starts)
  say ""
  say "Writing this computer's safety checks for this folder..."
  if (cd "$OPEN" && UV_PYTHON_DOWNLOADS=never "$UV" run --quiet ops/setup.py --from-install); then
    say ""
    say "DONE"
    say "NEXT: start a new conversation in this folder (the + button) and type /setup"
  else
    say ""
    say "DONE (the safety checks will be finished by /setup)"
    say "NEXT: start a new conversation in this folder (the + button) and type /setup"
  fi
  exit 0
fi

say ""
say "Done: the harness is in $OPEN"
say "Next:"
say "  1. Open the Claude app (download it from claude.ai/download if you don't have it) and sign in. If it was"
say "     already open, quit it and open it again, so it finds the tools this just added."
say "  2. Click Code, then choose the folder: $OPEN"
say "  3. Type /setup and press Enter. Claude guides you from there."
