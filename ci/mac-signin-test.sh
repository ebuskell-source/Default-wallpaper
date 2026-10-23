#!/bin/bash
# 5.7.0: signing in on a real Mac. Installs the test package, trusts test keys, then: the shared checks in
# JavaScriptCore, signed out (TLA Classic, greyed-out app), the whole sign-in round trip (tla-signin, signin.js,
# settings.zsh), signed in, time to sign in again, reminders, the guard's view, and pictures of the app.
set -u
O="$PWD/out/signin"; mkdir -p "$O"
D="/Library/Application Support/ca.schoolathome.welcomevideo"
log() { echo "== $*" >> "$O/summary.txt"; }
sudo installer -pkg ci/test.pkg -target / > "$O/install.txt" 2>&1; echo "installer: $?" >> "$O/install.txt"
defaults write ca.schoolathome.welcomevideo Channel experimental
defaults write ca.schoolathome.welcomevideo Background space
defaults write ca.schoolathome.welcomevideo Video space
defaults write ca.schoolathome.welcomevideo PreferredName Sevilen
pip3 install --quiet --break-system-packages cryptography >> "$O/pip.txt" 2>&1 || pip3 install --quiet cryptography >> "$O/pip.txt" 2>&1
sleep 12   # (the guard's first run fetches the real settings; the test ones go in after)
python3 ci/signin/prep.py /tmp/signin-test > "$O/prep.txt" 2>&1
sudo mkdir -p "$D/SignIn"; sudo cp /tmp/signin-test/auth.json /tmp/signin-test/keys.json "$D/SignIn/"; sudo touch "$D/.signin-checked"
sudo rm -f "$D"/SignIn/state-*
# (the release channels as they'll be once 5.7.0 is out on Experimental)
printf 'stable\t5.6.0\nexperimental\t5.7.0\n' | sudo tee "$D/channels.tsv" > /dev/null
log "channels"; cat "$D/channels.tsv" >> "$O/summary.txt"
log "files"; ls -la "$D/SignIn" "$D/signin.js" "$D/tla-signin" >> "$O/summary.txt" 2>&1
file "$D/tla-signin" >> "$O/summary.txt"

log "shared checks (JavaScriptCore)"
osascript -l JavaScript ci/signin/run-vectors.js "$PWD/ci/signin/signin-core.js" "$PWD/ci/signin/vectors.json" >> "$O/summary.txt" 2>&1

U="$(ioreg -rd1 -c IOPlatformExpertDevice | sed -n 's/.*"IOPlatformUUID" = "\(.*\)".*/\1/p')"
DEV="mac:$U"; ME="$(id -un)"
tok() {   # tok <days ago>: a test Hub token for this Mac and account, saved as their sign-in
  local salt=c2FsdHNhbHRzYWx0c2FsdA n
  n="$(python3 ci/signin/mktoken.py nonce "$DEV" "$ME" "$salt")"
  defaults write ca.schoolathome.welcomevideo SignInToken "$(python3 ci/signin/mktoken.py token hub $(( $(date +%s) - $1 * 86400 )) "$n")"
  defaults write ca.schoolathome.welcomevideo SignInSalt "$salt"
}
status() { /usr/bin/time -p osascript -l JavaScript "$D/signin.js" status 2>> "$O/time.txt"; }

log "signed out"
status >> "$O/summary.txt" 2>&1
zsh -c 'source "$1/common.zsh"; print -r -- "Background=$(wv_setting Background) Video=$(wv_setting Video) current=$(wv_current_background) channel=$(wv_channel) save:"; zsh "$1/settings.zsh" --save Background code; print "exit $?"' t "$D" >> "$O/summary.txt" 2>&1
mkdir -p "$O/out"; TB_TEST="$O/out" zsh "$D/settings.zsh" > "$O/out/result.txt" 2>&1

log "round trip"
f="$(TB_SIGNIN_NO_BROWSER=1 zsh "$D/settings.zsh" --signin start)"; echo "answer file: $f" >> "$O/summary.txt"
url="$(cat "${f%/answer}/url")"; port="$(cat "${f%/answer}/port")"; echo "url: ${url:0:110} port: $port" >> "$O/summary.txt"
nonce="$(python3 -c 'import sys,urllib.parse as u; print(dict(u.parse_qsl(u.urlsplit(sys.argv[1]).query))["nonce"])' "$url")"
state="$(python3 -c 'import sys,urllib.parse as u; print(dict(u.parse_qsl(u.urlsplit(sys.argv[1]).query))["state"])' "$url")"
curl -s -o /dev/null -w 'favicon: %{http_code}\n' "http://127.0.0.1:$port/favicon.ico" >> "$O/summary.txt"
t="$(python3 ci/signin/mktoken.py token hub $(date +%s) "$nonce")"
curl -s -D - -o /dev/null "http://127.0.0.1:$port/callback?state=$state&token=$t" | head -2 >> "$O/summary.txt"
sleep 0.5; ls -la "$f" >> "$O/summary.txt" 2>&1
zsh "$D/settings.zsh" --signin finish "$f" >> "$O/summary.txt" 2>&1
zsh "$D/settings.zsh" --signin status >> "$O/summary.txt" 2>&1
zsh -c 'source "$1/common.zsh"; print -r -- "Background=$(wv_setting Background) Video=$(wv_setting Video) current=$(wv_current_background)"' t "$D" >> "$O/summary.txt" 2>&1
mkdir -p "$O/in"; TB_TEST="$O/in" zsh "$D/settings.zsh" > "$O/in/result.txt" 2>&1

log "wrong state, cancel"
f="$(TB_SIGNIN_NO_BROWSER=1 zsh "$D/settings.zsh" --signin start)"; port="$(cat "${f%/answer}/port")"
curl -s -o /dev/null "http://127.0.0.1:$port/callback?state=1.xxxxxxxxxxxxxxxxxxxx&token=$t"; sleep 0.5
zsh "$D/settings.zsh" --signin finish "$f" >> "$O/summary.txt" 2>&1
f="$(TB_SIGNIN_NO_BROWSER=1 zsh "$D/settings.zsh" --signin start)"; zsh "$D/settings.zsh" --signin cancel "$f"; echo "cancelled: $(ls "${f%/answer}" 2>&1 | head -1); helper left: $(pgrep -f tla-signin | wc -l)" >> "$O/summary.txt"

log "time to sign in again (25 days ago), reminders"
tok 25; status >> "$O/summary.txt" 2>&1
osascript -l JavaScript "$D/signin.js" remind >> "$O/summary.txt" 2>&1; echo "(again:) [$(osascript -l JavaScript "$D/signin.js" remind 2>&1)]" >> "$O/summary.txt"
mkdir -p "$O/renew"; TB_TEST="$O/renew" zsh "$D/settings.zsh" > "$O/renew/result.txt" 2>&1
tok 28; osascript -l JavaScript "$D/signin.js" remind >> "$O/summary.txt" 2>&1

log "ran out (31 days ago; online), edited token, another account"
tok 31; status >> "$O/summary.txt" 2>&1
python3 - "$(defaults read ca.schoolathome.welcomevideo SignInToken)" <<'PY' > /tmp/edited.txt
import sys, json, base64
h, p, s = sys.argv[1].split('.')
b = json.loads(base64.urlsafe_b64decode(p + '=' * (-len(p) % 4))); b['iat'] += 20 * 86400
print(h + '.' + base64.urlsafe_b64encode(json.dumps(b).encode()).rstrip(b'=').decode() + '.' + s)
PY
defaults write ca.schoolathome.welcomevideo SignInToken "$(cat /tmp/edited.txt)"; status >> "$O/summary.txt" 2>&1
tok 1; defaults write ca.schoolathome.welcomevideo SignInSalt c2FsdHNhbHRzYWx0c2FsdB; status >> "$O/summary.txt" 2>&1

log "the guard (root), signed in"
tok 2
sudo zsh "$D/guard.zsh"; uid=$(id -u); echo "cache: $(sudo cat "$D/SignIn/state-$uid" 2>&1)" >> "$O/summary.txt"
log "sign out"
zsh "$D/settings.zsh" --signin out; status >> "$O/summary.txt" 2>&1

log "status timing (real seconds)"; grep real "$O/time.txt" | head -20 | tr '\n' ' ' >> "$O/summary.txt"; echo >> "$O/summary.txt"
log "log"; cat ~/Library/Logs/"TLA BootPaper.log" >> "$O/summary.txt" 2>/dev/null
sudo tail -20 /Library/Logs/ca.schoolathome.welcomevideo.log >> "$O/summary.txt" 2>/dev/null
