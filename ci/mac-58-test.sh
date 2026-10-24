#!/bin/bash
# 5.8.0: the app's own program running the window (in the Dock, with menus), and Check for updates through guard.zsh.
set -u
O=out/m58; mkdir -p $O
D="/Library/Application Support/ca.schoolathome.welcomevideo"
APP="/Applications/TLA BootPaper.app"
sudo installer -pkg ci/test.pkg -target / > $O/install.txt 2>&1; echo "installer: $?" >> $O/install.txt
defaults write ca.schoolathome.welcomevideo Channel experimental
defaults write ca.schoolathome.welcomevideo PreferredName Sevilen
sleep 5
cat > /tmp/t.js <<'JS'
ObjC.import('AppKit');
function run(argv) { return 'args=' + JSON.stringify(argv) + ' bundle=' + $.NSBundle.mainBundle.bundleIdentifier.js; }
JS
"$APP/Contents/MacOS/welcome-video" --jxa /tmp/t.js one "two words" > $O/host.txt 2>&1; echo "rc $?" >> $O/host.txt
echo 'function run(argv) { return nope( }' > /tmp/bad.js
"$APP/Contents/MacOS/welcome-video" --jxa /tmp/bad.js > $O/host-bad.txt 2>&1; echo "rc $?" >> $O/host-bad.txt
TB_TEST="$PWD/$O" zsh "$D/settings.zsh" > $O/result.txt 2>&1; echo "exit $?" >> $O/result.txt
# Opened like a person would: in the Dock, with its own menu bar?
open "$APP"; sleep 10
lsappinfo list > $O/lsappinfo.txt 2>&1
osascript -e 'tell application "System Events" to get name of every process whose background only is false' > $O/foreground.txt 2>&1
osascript -e 'tell application "System Events" to get name of every menu bar item of menu bar 1 of (first process whose frontmost is true)' > $O/menubar.txt 2>&1
osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' > $O/front.txt 2>&1
screencapture -x $O/screen.png
# Quit (as from the Dock): the window goes, and settings.zsh doesn't open it again in osascript
osascript -e 'tell application "System Events" to keystroke "q" using command down' > $O/quit.txt 2>&1; sleep 4
pgrep -fl 'welcome-video|osascript|settings.zsh' > $O/after-quit.txt 2>&1; echo "pgrep $?" >> $O/after-quit.txt
screencapture -x $O/screen-after-quit.png
# Check for updates (guard.zsh answers within about 20 seconds)
at=$(zsh "$D/settings.zsh" --care-fix update); echo "asked at '$at'" > $O/update.txt
r=''
for i in $(seq 1 30); do r=$(zsh "$D/settings.zsh" --care-result update "$at"); [[ -n "$r" ]] && break; sleep 3; done
echo "answer after ${i}x3s: $r" >> $O/update.txt
tail -15 /Library/Logs/ca.schoolathome.welcomevideo.log >> $O/update.txt 2>&1
cp ~/Library/Logs/"TLA BootPaper.log" $O/log.txt 2>/dev/null
