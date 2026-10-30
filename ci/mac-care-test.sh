#!/bin/bash
# 7.0: "Check my Mac" in the app doesn't open TLA Care. Open the app as people do, click it, and see what happens.
set -u
O="$PWD/out/care"; mkdir -p "$O"; D="/Library/Application Support/ca.schoolathome.welcomevideo"
sudo installer -pkg ci/test.pkg -target / > /dev/null 2>&1; sleep 10
defaults write ca.schoolathome.welcomevideo Channel experimental
open -a "/Applications/TLA BootPaper.app"; sleep 8
osascript -e 'tell application "System Events" to tell process "welcome-video" to get name of every button of window 1' >> "$O/summary.txt" 2>&1
osascript -e 'tell application "System Events" to tell process "welcome-video" to click button "Check my Mac" of window 1' >> "$O/summary.txt" 2>&1
sleep 15; screencapture -x -t jpg "$O/after-click.jpg"
echo "processes:" >> "$O/summary.txt"; pgrep -fl 'care-app|settings.zsh' >> "$O/summary.txt"
osascript -e 'tell application "System Events" to get name of every window of every process whose name is "osascript"' >> "$O/summary.txt" 2>&1
echo "--- log" >> "$O/summary.txt"; grep -E "TLA Care|App window|care" /Library/Logs/ca.schoolathome.welcomevideo.log | tail -8 >> "$O/summary.txt"
echo "--- direct" >> "$O/summary.txt"; time (zsh "$D/settings.zsh" --care-checks | cut -c1-80) >> "$O/summary.txt" 2>&1
( zsh "$D/settings.zsh" --care > "$O/direct.txt" 2>&1 & ); sleep 12; screencapture -x -t jpg "$O/direct.jpg"
pgrep -fl 'care-app' >> "$O/summary.txt"; tail -3 /Library/Logs/ca.schoolathome.welcomevideo.log >> "$O/summary.txt"
echo done >> "$O/summary.txt"
