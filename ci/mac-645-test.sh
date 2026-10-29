#!/bin/bash
# 6.4.5 on the Mac (Apple silicon or Intel): the new backgrounds, the sign-in inside the lock screen (nothing else can be
# used meanwhile), the tour at login on TLA's Macs, and the app and tour themselves.
set -u
O="$PWD/out/m645-$(uname -m)"; mkdir -p "$O/app" "$O/tour" "$O/shots"
D="/Library/Application Support/ca.schoolathome.welcomevideo"; A="/Applications/TLA BootPaper.app"
log() { echo "== $*" >> "$O/summary.txt"; }
{ sw_vers | tr '\n' ' '; uname -m; } >> "$O/summary.txt"
sudo installer -pkg ci/test.pkg -target / > "$O/install.txt" 2>&1; echo "installer: $?" >> "$O/summary.txt"
launchctl bootout "gui/$(id -u)/ca.schoolathome.welcomevideo.lock" 2>/dev/null
pip3 install --quiet --break-system-packages cryptography > /dev/null 2>&1 || pip3 install --quiet cryptography > /dev/null 2>&1
sleep 12; sudo launchctl bootout system/ca.schoolathome.welcomevideo.guard 2>/dev/null
python3 ci/signin/prep.py /tmp/signin-test > "$O/prep.txt" 2>&1
sudo mkdir -p "$D/SignIn"; sudo cp /tmp/signin-test/auth.json /tmp/signin-test/keys.json "$D/SignIn/"; sudo touch "$D/.signin-checked"
printf 'stable\t6.4.5\nexperimental\t6.4.5\n' | sudo tee "$D/channels.tsv" > /dev/null
defaults delete ca.schoolathome.welcomevideo SignInToken 2>/dev/null
U="$(ioreg -rd1 -c IOPlatformExpertDevice | sed -n 's/.*"IOPlatformUUID" = "\(.*\)".*/\1/p')"; DEV="mac:$U"; ME="$(id -un)"
tok() { local salt=c2FsdHNhbHRzYWx0c2FsdA n
  n="$(python3 ci/signin/mktoken.py nonce "$DEV" "$ME" "$salt")"
  defaults write ca.schoolathome.welcomevideo SignInToken "$(python3 ci/signin/mktoken.py token hub $(( $(date +%s) - $1 * 86400 )) "$n")"
  defaults write ca.schoolathome.welcomevideo SignInSalt "$salt"; }
locks() { pgrep -f 'lock-app\.js' | wc -l | tr -d ' '; }

log "backgrounds"
zsh -c 'source "$1/common.zsh"; for d in 2026-12-25 2027-01-07 2027-02-14 2027-03-19 2027-03-20; do print -n "$d=$(wv_season $d) "; done; print; for b in pixel vancouver winter; do print "$b $(wv_background_path $b) $(wv_background_path $b dark)"; done; print "names: ${WV_BACKGROUND_NAMES[(r)Vancouver]} seasons: $WV_SEASONAL"' t "$D" >> "$O/summary.txt" 2>&1
ls "$D/Backgrounds" | grep -E 'pixel|vancouver|winter' | tr '\n' ' ' >> "$O/summary.txt"; echo >> "$O/summary.txt"
log "videos (sync)"; sudo zsh "$D/sync-videos.zsh" > /dev/null 2>&1; ls -la "$D/Videos" | grep -E 'pixel|winter' >> "$O/summary.txt"
shasum -a 256 "$D/Videos/pixel.mp4" "$D/Videos/winter.mp4" "$D/Videos/winter-dark.mp4" >> "$O/summary.txt" 2>&1

log "the app and the tour (pictures)"
defaults write ca.schoolathome.welcomevideo Background vancouver; tok 1
TB_TEST="$O/app" zsh "$D/settings.zsh" > "$O/app/result.txt" 2>&1; echo "app self-test exit $?: $(head -c 200 "$O/app/result.txt")" >> "$O/summary.txt"
grep -i "App window" /Library/Logs/ca.schoolathome.welcomevideo.log | tail -3 >> "$O/summary.txt"
open -a "$A"; sleep 8; screencapture -x -t jpg "$O/shots/0-app-opened.jpg"; echo "app windows: $(osascript -e 'tell application "System Events" to get name of every window of (every process whose name is "welcome-video")' 2>&1)" >> "$O/summary.txt"
osascript -e 'tell application "TLA BootPaper" to quit' 2>/dev/null; sleep 2; pkill -f settings-app.js

log "TLA's Mac, signed out: lock screen, Sign in inside it"
defaults delete ca.schoolathome.welcomevideo SignInToken
echo dep | sudo tee "$D/Care/enrollment" > /dev/null
zsh "$D/settings.zsh" --state tour | grep -E '^(signin|corporate)' | cut -c1-40 >> "$O/summary.txt"
zsh "$D/settings.zsh" --lock-check > /dev/null 2>&1 &
for i in $(seq 1 40); do [ "$(locks)" != 0 ] && break; sleep 1; done; echo "lock screens: $(locks) after ${i}s" >> "$O/summary.txt"
sleep 3; screencapture -x -t jpg "$O/shots/1-lock.jpg"
pid="$(pgrep -f 'lock-app\.js' | head -1)"
osascript -e "tell application \"System Events\" to click button \"Sign in\" of window 1 of (first process whose unix id is $pid)" >> "$O/summary.txt" 2>&1
sleep 8; screencapture -x -t jpg "$O/shots/2-signing-in.jpg"
echo "front: $(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>&1)" >> "$O/summary.txt"
open -a TextEdit; sleep 4; screencapture -x -t jpg "$O/shots/3-textedit-tried.jpg"
echo "front after TextEdit: $(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>&1)" >> "$O/summary.txt"
# Finish signing in as the sign-in page would: its answer to the waiting helper.
f="$(ls -d /tmp/tla-signin.* 2>/dev/null | tail -1)"; url="$(cat "$f/url" 2>/dev/null)"; port="$(cat "$f/port" 2>/dev/null)"
echo "url: ${url:0:90} port: $port" >> "$O/summary.txt"
nonce="$(python3 -c 'import sys,urllib.parse as u; print(dict(u.parse_qsl(u.urlsplit(sys.argv[1]).query))["nonce"])' "$url" 2>/dev/null)"
state="$(python3 -c 'import sys,urllib.parse as u; print(dict(u.parse_qsl(u.urlsplit(sys.argv[1]).query))["state"])' "$url" 2>/dev/null)"
t="$(python3 ci/signin/mktoken.py token hub $(date +%s) "$nonce")"
curl -s -o /dev/null -w 'callback: %{http_code}\n' "http://127.0.0.1:$port/callback?state=$state&token=$t" >> "$O/summary.txt"
for i in $(seq 1 30); do [ "$(locks)" = 0 ] && break; sleep 1; done; echo "lock screens: $(locks) ${i}s after signing in" >> "$O/summary.txt"
zsh "$D/settings.zsh" --signin status | cut -f1,2,7 >> "$O/summary.txt"
osascript -e 'tell application "TextEdit" to quit' 2>/dev/null

log "login on TLA's Mac, signed out: the tour (no video)"
defaults delete ca.schoolathome.welcomevideo SignInToken; defaults write ca.schoolathome.welcomevideo Enabled -int 0
zsh "$D/play-welcome-video.zsh" > /dev/null 2>&1 &
for i in $(seq 1 40); do pgrep -f 'tour-app\.js' > /dev/null && break; sleep 1; done; echo "tour after ${i}s: $(pgrep -f 'tour-app\.js' | wc -l | tr -d ' ')" >> "$O/summary.txt"
sleep 3; screencapture -x -t jpg "$O/shots/4-login-tour.jpg"; pkill -f 'tour-app\.js'; pkill -f play-welcome-video
TB_TEST="$O/tour" "$A/Contents/MacOS/welcome-video" --jxa "$D/tour-app.js" "$D/settings.zsh" app > "$O/tour/result.txt" 2>&1; echo "tour self-test: $(ls "$O/tour" | wc -l) pictures" >> "$O/summary.txt"
log "log"; tail -25 /Library/Logs/ca.schoolathome.welcomevideo.log >> "$O/summary.txt"
echo done >> "$O/summary.txt"
