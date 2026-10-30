#!/bin/bash
# 7.0.5: a TLA Mac, signed out, with the Welcome to TLA tour open: no lock while the tour is in front; once another app
# is in front (the tour left behind it), the lock screen.
set -u
O="$PWD/out/tourlock"; mkdir -p "$O"; D="/Library/Application Support/ca.schoolathome.welcomevideo"
sudo installer -pkg ci/test.pkg -target / > /dev/null 2>&1; echo "installed: $(awk -F'"' '/^WV_RELEASE=/ { print $2; exit }' "$D/common.zsh")" >> "$O/summary.txt"
launchctl bootout "gui/$(id -u)/ca.schoolathome.welcomevideo.lock" 2>/dev/null
pip3 install --quiet --break-system-packages cryptography > /dev/null 2>&1 || pip3 install --quiet cryptography > /dev/null 2>&1
sleep 10; sudo launchctl bootout system/ca.schoolathome.welcomevideo.guard 2>/dev/null
python3 ci/signin/prep.py /tmp/signin-test > /dev/null 2>&1
sudo mkdir -p "$D/SignIn"; sudo cp /tmp/signin-test/auth.json /tmp/signin-test/keys.json "$D/SignIn/"; sudo touch "$D/.signin-checked"
printf 'stable\t6.5.0\nexperimental\t7.0.5\n' | sudo tee "$D/channels.tsv" > /dev/null
defaults delete ca.schoolathome.welcomevideo SignInToken 2>/dev/null; echo dep | sudo tee "$D/Care/enrollment" > /dev/null
locks() { pgrep -f 'lock-app\.js' | wc -l | tr -d ' '; }
/usr/bin/osascript -l JavaScript "$D/tour-app.js" "$D/settings.zsh" app > /dev/null 2>&1 &
sleep 8; tp="$(pgrep -f 'tour-app\.js' | head -1)"
echo "tour pid $tp; front: $(lsappinfo info -only pid "$(lsappinfo front)")" >> "$O/summary.txt"
zsh "$D/settings.zsh" --lock-check > /dev/null 2>&1 &
sleep 8; echo "tour in front: $(locks) lock screens" >> "$O/summary.txt"; screencapture -x -t jpg "$O/1-tour-front.jpg"
pkill -f 'lock-app\.js'; wait
open -a TextEdit; sleep 4; echo "front now: $(lsappinfo info -only pid "$(lsappinfo front)")" >> "$O/summary.txt"
zsh "$D/settings.zsh" --lock-check > /dev/null 2>&1 &
for i in $(seq 1 20); do [ "$(locks)" != 0 ] && break; sleep 1; done
echo "tour behind TextEdit: $(locks) lock screens after ${i}s" >> "$O/summary.txt"; sleep 2; screencapture -x -t jpg "$O/2-tour-behind.jpg"
echo done >> "$O/summary.txt"
