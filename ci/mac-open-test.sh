#!/bin/bash
# Opening the TLA BootPaper app, putting another app in front, opening it again, closing the window and opening it
# again: which processes are left each time, what macOS thinks is running (lsappinfo), and what's on screen.
# PKG: the package to test (the published 5.9.5 by default).
set -u
O="$PWD/out/open"; mkdir -p "$O"
A="/Applications/TLA BootPaper.app"
PKG="${PKG:-}"
if [[ -z "$PKG" ]]; then
  curl -sfL -o /tmp/t.pkg https://raw.githubusercontent.com/ebuskell-source/Default-wallpaper/main/TLA-BootPaper/mac/TLA-BootPaper-5.9.5.pkg; PKG=/tmp/t.pkg
fi
sudo installer -pkg "$PKG" -target / > "$O/install.txt" 2>&1; echo "installer: $?" >> "$O/install.txt"
defaults write ca.schoolathome.welcomevideo Channel experimental
sleep 25
snap() {
  { echo; echo "== $1 ($(date +%T))"
    ps -axo pid,ppid,stat,etime,command | grep -E "welcome-video|settings\.zsh|settings-app|osascript|Dialog" | grep -v grep
    echo "-- lsappinfo:"; lsappinfo list 2>/dev/null | grep -B1 -A8 -i "bootpaper" | grep -E "BootPaper|pid|type|bundleID|executable" | head -20
    echo "-- front: $(lsappinfo info -only name "$(lsappinfo front)" 2>/dev/null)"
    echo "-- windows: $(osascript -l JavaScript -e 'ObjC.import("CoreGraphics"); const l = ObjC.deepUnwrap(ObjC.castRefToObject($.CGWindowListCopyWindowInfo(0, 0))); l.filter(w => /BootPaper|welcome-video/i.test(w.kCGWindowOwnerName || "")).map(w => w.kCGWindowOwnerName + " pid " + w.kCGWindowOwnerPID + " layer " + w.kCGWindowLayer + " onscreen " + w.kCGWindowIsOnscreen + " alpha " + w.kCGWindowAlpha + " " + JSON.stringify(w.kCGWindowBounds) + " " + (w.kCGWindowName || "")).join(" | ")' 2>&1)"
    echo "-- saved state: $(ls ~/Library/Saved\ Application\ State 2>&1 | grep -i welcome)"
    for p in $(pgrep -f "welcome-video --jxa"); do sudo sample "$p" 1 -file "$O/$1-sample-$p.txt" >/dev/null 2>&1; echo "-- sampled $p"; done
  } >> "$O/summary.txt"
  screencapture -x -t jpg "$O/$1.jpg"
}
snap 0-before
open -a "$A"; sleep 12; snap 1-opened
open -a Calculator; sleep 4; snap 2-calculator-in-front
open -a "$A"; sleep 6; snap 3-opened-again
echo "-- closing with Cmd-W:" >> "$O/summary.txt"
osascript -e 'tell application "System Events" to tell process "TLA BootPaper" to set frontmost to true' -e 'delay 1' \
          -e 'tell application "System Events" to keystroke "w" using command down' >> "$O/summary.txt" 2>&1
sleep 8; snap 4-closed
open -a "$A"; sleep 12; snap 5-opened-after-close
echo "-- quit app:" >> "$O/summary.txt"
osascript -e 'quit app "TLA BootPaper"' >> "$O/summary.txt" 2>&1; sleep 6; snap 6-quit
open -a "$A"; sleep 12; snap 7-opened-after-quit
cp ~/Library/Logs/"TLA BootPaper.log" "$O/log.txt" 2>/dev/null
