#!/bin/bash
# 6.2.5 on the Mac: signing in is required on TLA's Macs (Care/enrollment = dep): the tour (no Skip), and the lock
# screen (never signed in, then run out), which goes away by itself once they're signed in. Then a Mac of their own.
set -u
O="$PWD/out/m625"; mkdir -p "$O/tour-corp" "$O/tour-own" "$O/shots"
D="/Library/Application Support/ca.schoolathome.welcomevideo"
log() { echo "== $*" >> "$O/summary.txt"; }
sudo installer -pkg ci/test.pkg -target / > "$O/install.txt" 2>&1; echo "installer: $?" >> "$O/install.txt"
log "lock agent after install"; launchctl print "gui/$(id -u)/ca.schoolathome.welcomevideo.lock" 2>&1 | grep -E "state|path|run interval|last exit" >> "$O/summary.txt"
launchctl bootout "gui/$(id -u)/ca.schoolathome.welcomevideo.lock" 2>/dev/null
pip3 install --quiet --break-system-packages cryptography > "$O/pip.txt" 2>&1 || pip3 install --quiet cryptography >> "$O/pip.txt" 2>&1
sleep 12
sudo launchctl bootout system/ca.schoolathome.welcomevideo.guard 2>/dev/null   # (so it doesn't redo enrollment meanwhile)
python3 ci/signin/prep.py /tmp/signin-test > "$O/prep.txt" 2>&1
sudo mkdir -p "$D/SignIn"; sudo cp /tmp/signin-test/auth.json /tmp/signin-test/keys.json "$D/SignIn/"; sudo touch "$D/.signin-checked"
printf 'stable\t6.2.5\nexperimental\t6.2.5\n' | sudo tee "$D/channels.tsv" > /dev/null
defaults delete ca.schoolathome.welcomevideo SignInToken 2>/dev/null
U="$(ioreg -rd1 -c IOPlatformExpertDevice | sed -n 's/.*"IOPlatformUUID" = "\(.*\)".*/\1/p')"; DEV="mac:$U"; ME="$(id -un)"
tok() { local salt=c2FsdHNhbHRzYWx0c2FsdA n
  n="$(python3 ci/signin/mktoken.py nonce "$DEV" "$ME" "$salt")"
  defaults write ca.schoolathome.welcomevideo SignInToken "$(python3 ci/signin/mktoken.py token hub $(( $(date +%s) - $1 * 86400 )) "$n")"
  defaults write ca.schoolathome.welcomevideo SignInSalt "$salt"; }
check() { zsh -c 'source "$1/common.zsh"; print -r -- "enrollment=$(cat "$1/Care/enrollment" 2>/dev/null) corporate=$(wv_corporate && echo 1 || echo 0) signin=${WV_SIGNIN//	/|} online=$(wv_online && echo 1 || echo 0) needed=$(wv_lock_needed && echo 1 || echo 0)"' t "$D"; }
locks() { pgrep -fl 'lock-app\.js' | wc -l | tr -d ' '; }
echo dep | sudo tee "$D/Care/enrollment" > /dev/null

log "TLA's Mac, never signed in"; check >> "$O/summary.txt" 2>&1
zsh "$D/settings.zsh" --state tour | grep -E '^(signin|corporate)' >> "$O/summary.txt"
TB_TEST="$O/tour-corp" /usr/bin/osascript -l JavaScript "$D/tour-app.js" "$D/settings.zsh" app > "$O/tour-corp/result.txt" 2>&1
TB_TEST="$O/shots" "/Applications/TLA BootPaper.app/Contents/MacOS/welcome-video" --jxa "$D/lock-app.js" "$D/settings.zsh" > "$O/shots/lock-test.txt" 2>&1
mv "$O/shots/lock.png" "$O/shots/1-never.png" 2>/dev/null

log "the agent starts it"
launchctl bootstrap "gui/$(id -u)" /Library/LaunchAgents/ca.schoolathome.welcomevideo.lock.plist 2>> "$O/summary.txt"
sleep 10; echo "lock screens running: $(locks)" >> "$O/summary.txt"; screencapture -x -t jpg "$O/shots/2-agent.jpg"
# Something else tries to come in front: it covers it again.
open -a TextEdit; sleep 4; screencapture -x -t jpg "$O/shots/3-textedit-tried.jpg"
echo "front: $(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>&1)" >> "$O/summary.txt"

log "signed in elsewhere (as if in the browser): it goes away"
t0=$(date +%s); tok 1
for i in $(seq 1 30); do [ "$(locks)" = 0 ] && break; sleep 1; done
echo "lock screens running: $(locks) after $(( $(date +%s) - t0 ))s" >> "$O/summary.txt"; check >> "$O/summary.txt" 2>&1
screencapture -x -t jpg "$O/shots/4-signed-in.jpg"
osascript -e 'tell application "TextEdit" to quit' 2>/dev/null

log "run out (40 days ago): back within a minute"
tok 40; check >> "$O/summary.txt" 2>&1
for i in $(seq 1 75); do [ "$(locks)" != 0 ] && break; sleep 1; done
echo "lock screens running: $(locks) after ${i}s" >> "$O/summary.txt"; sleep 3; screencapture -x -t jpg "$O/shots/5-ran-out.jpg"
log "Log out button and Sign in button exist"
osascript -e 'tell application "System Events" to get name of every button of every window of (first process whose unix id is '"$(pgrep -f 'lock-app\.js' | head -1)"')' >> "$O/summary.txt" 2>&1
log "Sign in: steps aside for the browser"
osascript -e 'tell application "System Events" to click button "Sign in" of window 1 of (first process whose unix id is '"$(pgrep -f 'lock-app\.js' | head -1)"')' >> "$O/summary.txt" 2>&1
sleep 6; screencapture -x -t jpg "$O/shots/6-signing-in.jpg"
echo "front: $(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>&1)" >> "$O/summary.txt"
ls -d /tmp/tla-signin.* >> "$O/summary.txt" 2>&1
tok 1; for i in $(seq 1 30); do [ "$(locks)" = 0 ] && break; sleep 1; done
echo "lock screens running: $(locks) after signing in" >> "$O/summary.txt"; echo "helpers left: $(pgrep -f tla-signin | wc -l)" >> "$O/summary.txt"

log "offline-style: needed only when online (the check itself)"; check >> "$O/summary.txt" 2>&1
log "a Mac of their own, never signed in: no lock, Skip stays"
defaults delete ca.schoolathome.welcomevideo SignInToken
echo none | sudo tee "$D/Care/enrollment" > /dev/null; check >> "$O/summary.txt" 2>&1
sleep 65; echo "lock screens running: $(locks)" >> "$O/summary.txt"
TB_TEST="$O/tour-own" /usr/bin/osascript -l JavaScript "$D/tour-app.js" "$D/settings.zsh" app > "$O/tour-own/result.txt" 2>&1
log "release"; zsh -c 'source "$1/common.zsh"; print -r -- "$WV_RELEASE $(wv_channel_release)"' t "$D" >> "$O/summary.txt"
tail -20 /Library/Logs/ca.schoolathome.welcomevideo.log > "$O/log.txt" 2>&1
echo done >> "$O/summary.txt"
