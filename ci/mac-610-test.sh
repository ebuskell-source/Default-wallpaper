#!/bin/bash
# 6.1.0 on the Mac: TLA's sections (pictures of the app and the tour), a window left open across an update (it says so,
# and Restart opens the new one), and Check for updates with its progress bar, start to finish: the installed copy is
# made to look like 6.0.0, so the version GitHub has (mac/latest.json) is newer and gets installed.
set -u
O="$PWD/out/m610"; mkdir -p "$O/app" "$O/tour" "$O/upd"
D="/Library/Application Support/ca.schoolathome.welcomevideo"
A="/Applications/TLA BootPaper.app"
LOG=/Library/Logs/ca.schoolathome.welcomevideo.log
log() { echo "== $*" >> "$O/summary.txt"; }
sudo installer -pkg ci/test.pkg -target / > "$O/install.txt" 2>&1; echo "installer: $?" >> "$O/install.txt"
defaults write ca.schoolathome.welcomevideo Channel experimental
defaults write ca.schoolathome.welcomevideo PreferredName Sevilen
for i in $(seq 1 90); do sudo grep -q 'Release channels:' $LOG 2>/dev/null && break; sleep 2; done
sleep 5
# GitHub still says 6.0.5 is the newest: 6.1.0's things show for 6.1.0 here.
printf 'stable\t6.1.0\nexperimental\t6.1.0\n' | sudo tee "$D/channels.tsv" > /dev/null
log "pictures: the app and the tour"
TB_TEST="$O/app" zsh "$D/settings.zsh" > "$O/app/result.txt" 2>&1; echo "self-test exit $?" >> "$O/summary.txt"
TB_TEST="$O/tour" /usr/bin/osascript -l JavaScript "$D/tour-app.js" "$D/settings.zsh" app > "$O/tour/result.txt" 2>&1
cat "$O/app/video-menu.txt" "$O/app/tiles.txt" >> "$O/summary.txt" 2>&1
log "a window left open while a newer version is installed"
open -a "$A"; sleep 8
sudo sed -i '' 's/^WV_RELEASE="6.1.0"/WV_RELEASE="6.1.5"/' "$D/common.zsh"
sleep 14; screencapture -x -t jpg "$O/upd/stale-1.jpg"
osascript -e 'tell application "System Events" to tell process "TLA BootPaper" to set frontmost to true' -e 'delay 1' \
  -e 'tell application "System Events" to tell process "TLA BootPaper" to click (first button of entire contents of window 1 whose name is "Restart TLA BootPaper")' >> "$O/summary.txt" 2>&1
echo "before: $(pgrep -f 'MacOS/welcome-video' | tr '\n' ' ')" >> "$O/summary.txt"
sleep 8; echo "after restart: $(pgrep -f 'MacOS/welcome-video' | tr '\n' ' ')" >> "$O/summary.txt"
screencapture -x -t jpg "$O/upd/stale-2-restarted.jpg"
sudo sed -i '' 's/^WV_RELEASE="6.1.5"/WV_RELEASE="6.1.0"/' "$D/common.zsh"
osascript -e 'with timeout of 20 seconds' -e 'quit app "TLA BootPaper"' -e 'end timeout' >> "$O/summary.txt" 2>&1; sleep 3
log "Check for updates, start to finish (made to look like 6.0.0)"
sudo sed -i '' 's/^WV_RELEASE="6.1.0"/WV_RELEASE="6.0.0"/' "$D/common.zsh"
TB_TEST="$O/upd" TB_TEST_UPDATE=1 zsh "$D/settings.zsh" > "$O/upd/result.txt" 2>&1; echo "self-test exit $?" >> "$O/summary.txt"
cat "$O/upd/update-texts.txt" >> "$O/summary.txt" 2>&1
grep '^WV_RELEASE=' "$D/common.zsh" >> "$O/summary.txt"
echo "Care/update: $(cat "$D/Care/update" 2>/dev/null)" >> "$O/summary.txt"
sudo grep -h "is out\|Updated to\|Installing TLA\|download" $LOG | tail -8 >> "$O/summary.txt"
sudo tail -60 $LOG > "$O/guard-log.txt" 2>&1
