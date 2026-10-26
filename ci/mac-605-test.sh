#!/bin/bash
# 6.0.5 on the Mac: the app opens every time (opened again, closed, quit from the Dock, minimized), pictures of the
# themed sections and the tour's background page, and the two new videos.
set -u
O="$PWD/out/m605"; mkdir -p "$O/app" "$O/tour"
D="/Library/Application Support/ca.schoolathome.welcomevideo"
A="/Applications/TLA BootPaper.app"
sudo installer -pkg ci/test.pkg -target / > "$O/install.txt" 2>&1; echo "installer: $?" >> "$O/install.txt"
defaults write ca.schoolathome.welcomevideo Channel experimental
defaults write ca.schoolathome.welcomevideo PreferredName Sevilen
for i in $(seq 1 90); do
  sudo grep -q 'Release channels:' /Library/Logs/ca.schoolathome.welcomevideo.log 2>/dev/null && break; sleep 2
done
sleep 5
snap() {
  { echo; echo "== $1 ($(date +%T))"
    ps -axo pid,ppid,stat,etime,command | grep -E "welcome-video|settings\.zsh|settings-app" | grep -v grep
    echo "-- lsappinfo:"; lsappinfo list 2>/dev/null | grep -A4 '"TLA BootPaper"' | grep -E "TLA BootPaper|pid" | head -6
    echo "-- front: $(lsappinfo info -only name "$(lsappinfo front)" 2>/dev/null)"
    echo "-- windows: $(osascript -l JavaScript -e 'ObjC.import("CoreGraphics"); const l = ObjC.deepUnwrap(ObjC.castRefToObject($.CGWindowListCopyWindowInfo(0, 0))); l.filter(w => /BootPaper/i.test(w.kCGWindowOwnerName || "") && w.kCGWindowBounds.Height > 100).map(w => "pid " + w.kCGWindowOwnerPID + " onscreen " + (w.kCGWindowIsOnscreen ? "yes" : "no") + " " + Math.round(w.kCGWindowBounds.Width) + "x" + Math.round(w.kCGWindowBounds.Height)).join(" | ")' 2>&1)"
  } >> "$O/summary.txt"
  screencapture -x -t jpg "$O/$1.jpg"
}
quit_app() { echo "-- quit ($1):" >> "$O/summary.txt"; osascript -e 'with timeout of 20 seconds' -e 'quit app "TLA BootPaper"' -e 'end timeout' >> "$O/summary.txt" 2>&1; echo "   exit $?" >> "$O/summary.txt"; }
touch /tmp/tb-debug
key() { osascript -e 'tell application "System Events" to tell process "TLA BootPaper" to set frontmost to true' -e 'delay 1' -e "tell application \"System Events\" to $1" >> "$O/summary.txt" 2>&1; }
open -a "$A"; sleep 8; snap 01-opened
quit_app "the first time"; sleep 4; snap 02-quit
open -a Calculator; sleep 3; open -a "$A"; sleep 8; snap 03-fresh-over-calculator
echo "-- Esc (the Close button):" >> "$O/summary.txt"; key 'key code 53'; sleep 5; snap 04-closed-with-esc
open -a "$A"; sleep 8; snap 05-opened-after-esc
echo "-- Cmd-W:" >> "$O/summary.txt"; key 'keystroke "w" using command down'; sleep 5; snap 06-closed-with-cmd-w
open -a "$A"; sleep 8; snap 07-opened-after-cmd-w
open -a Calculator; sleep 3; open -a "$A"; sleep 5; snap 08-opened-again-over-calculator
echo "-- Cmd-M:" >> "$O/summary.txt"; key 'keystroke "m" using command down'; sleep 3; open -a "$A"; sleep 5; snap 09-opened-while-minimized
quit_app "again"; sleep 4; snap 10-quit-again
open -a Calculator; sleep 3; open -a "$A"; sleep 8; snap 11-fresh-over-calculator
quit_app "to finish"; sleep 3; snap 12-end
{ echo; echo "== debug log"; cat /tmp/tb-debug.log; } >> "$O/summary.txt" 2>&1
rm -f /tmp/tb-debug
# Pictures: the app's themed sections, and the tour
TB_TEST="$O/app" zsh "$D/settings.zsh" > "$O/app/result.txt" 2>&1; echo "self-test exit $?" >> "$O/summary.txt"
TB_TEST="$O/tour" /usr/bin/osascript -l JavaScript "$D/tour-app.js" "$D/settings.zsh" app > "$O/tour/result.txt" 2>&1
defaults write -g AppleInterfaceStyle Dark
mkdir -p "$O/tour-dark"; TB_TEST="$O/tour-dark" /usr/bin/osascript -l JavaScript "$D/tour-app.js" "$D/settings.zsh" app > "$O/tour-dark/result.txt" 2>&1
defaults delete -g AppleInterfaceStyle
# The new videos
sudo zsh "$D/sync-videos.zsh"; echo "sync exit $?" >> "$O/summary.txt"
for v in code-light anime-dark anime code; do echo "$v: $(shasum -a 256 "$D/Videos/$v.mp4" 2>&1 | cut -c1-64)" >> "$O/summary.txt"; done
sudo grep -h "code-light\|anime-dark" /Library/Logs/ca.schoolathome.welcomevideo.log | tail -5 >> "$O/summary.txt"
zsh -c 'source "$1/common.zsh"; for m in light dark; do WV_APPEARANCE=$m; print -r -- "code in $m: $(wv_video_file code 2>/dev/null)"; done; print -r -- "names: ${WV_BACKGROUND_NAMES[*]}"' t "$D" >> "$O/summary.txt" 2>&1
cp ~/Library/Logs/"TLA BootPaper.log" "$O/log.txt" 2>/dev/null
