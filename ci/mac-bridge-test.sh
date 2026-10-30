#!/bin/bash
# A Mac that got 7.5.0 goes back to 7.0 by itself (its own update.zsh, against the published latest.json), and then stays.
set -u
O="$PWD/out/bridge"; mkdir -p "$O"; D="/Library/Application Support/ca.schoolathome.welcomevideo"
rel() { awk -F'"' '/^WV_RELEASE=/ { print $2; exit }' "$D/common.zsh"; }
sudo installer -pkg ci/test75.pkg -target / > /dev/null 2>&1; echo "installed: $(rel), app $(defaults read '/Applications/TLA BootPaper.app/Contents/Info.plist' CFBundleShortVersionString)" >> "$O/summary.txt"
sudo launchctl bootout system/ca.schoolathome.welcomevideo.update 2>/dev/null; sudo launchctl bootout system/ca.schoolathome.welcomevideo.guard 2>/dev/null
sudo rm -f "$D/.update-check"; sudo zsh "$D/update.zsh" >/dev/null 2>&1
echo "after its update check: $(rel), app $(defaults read '/Applications/TLA BootPaper.app/Contents/Info.plist' CFBundleShortVersionString)" >> "$O/summary.txt"
grep -n "release=" "$D/update.zsh" | head -2 >> "$O/summary.txt"
sudo rm -f "$D/.update-check"; sudo zsh "$D/update.zsh" >/dev/null 2>&1
echo "after another check: $(rel)" >> "$O/summary.txt"
grep -E "TLA BootPaper|Updated|is out" /Library/Logs/ca.schoolathome.welcomevideo.log | tail -6 >> "$O/summary.txt"
echo done >> "$O/summary.txt"
