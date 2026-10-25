#!/bin/bash
# 5.9.0: the animal backgrounds and intro videos, and their own pictures on a Mac of their own (a GitHub runner isn't
# set up through Apple School or Business Manager, so it's one). Signed in with a test sign-in, on Experimental.
set -u
O="$PWD/out/m59"; mkdir -p "$O/pictures" "$O/app"
D="/Library/Application Support/ca.schoolathome.welcomevideo"
OWN="$HOME/Library/Application Support/TLA BootPaper/Pictures"
log() { echo "== $*" >> "$O/summary.txt"; }
c() { zsh -c 'source "$1/common.zsh"; shift; eval "$*"' t "$D" "$@"; }
sudo installer -pkg ci/test.pkg -target / > "$O/install.txt" 2>&1; echo "installer: $?" >> "$O/install.txt"
defaults write ca.schoolathome.welcomevideo Channel experimental
defaults write ca.schoolathome.welcomevideo PreferredName Sevilen
pip3 install --quiet --break-system-packages cryptography > "$O/pip.txt" 2>&1 || pip3 install --quiet cryptography >> "$O/pip.txt" 2>&1
# The guard's first run (videos, the real sign-in settings and channels, how this Mac is enrolled) has to be over
# before the test settings go in, or it puts the real ones back.
for i in $(seq 1 90); do
  sudo grep -q 'Release channels:' /Library/Logs/ca.schoolathome.welcomevideo.log 2>/dev/null &&
    sudo grep -q 'Sign-in settings:' /Library/Logs/ca.schoolathome.welcomevideo.log 2>/dev/null && break
  sleep 2
done
sleep 5; echo "guard's first run over after about $((i * 2 + 5))s" >> "$O/summary.txt"

log "how this Mac is enrolled (macOS, then the guard's note)"
sudo profiles status -type enrollment >> "$O/summary.txt" 2>&1
cat "$D/Care/enrollment" >> "$O/summary.txt" 2>&1 || echo "(no note yet)" >> "$O/summary.txt"

# A test sign-in for this Mac, and the release channels as they'll be once 5.9.0 is out on Experimental.
python3 ci/signin/prep.py /tmp/signin-test > "$O/prep.txt" 2>&1
sudo mkdir -p "$D/SignIn"; sudo cp /tmp/signin-test/auth.json /tmp/signin-test/keys.json "$D/SignIn/"; sudo touch "$D/.signin-checked"
sudo rm -f "$D"/SignIn/state-*
U="$(ioreg -rd1 -c IOPlatformExpertDevice | sed -n 's/.*"IOPlatformUUID" = "\(.*\)".*/\1/p')"
salt=c2FsdHNhbHRzYWx0c2FsdA
n="$(python3 ci/signin/mktoken.py nonce "mac:$U" "$(id -un)" "$salt")"
defaults write ca.schoolathome.welcomevideo SignInToken "$(python3 ci/signin/mktoken.py token hub "$(date +%s)" "$n")"
defaults write ca.schoolathome.welcomevideo SignInSalt "$salt"
printf 'stable\t5.8.0\nexperimental\t5.9.0\n' | sudo tee "$D/channels.tsv" > /dev/null
log "sign-in, channel, what's out"
zsh "$D/settings.zsh" --signin status >> "$O/summary.txt" 2>&1
c 'print -r -- "release=$WV_RELEASE channel=$(wv_channel) animals=$(for a in $WV_ANIMALS; do wv_released $a && print -n "$a "; done) own allowed=$(wv_own_allowed && print yes || print no) owned by TLA=$(wv_owned_by_tla && print yes || print no)"' >> "$O/summary.txt" 2>&1

log "the animal videos (downloaded and checked by the guard)"
sudo zsh "$D/sync-videos.zsh" >> "$O/sync.txt" 2>&1; echo "sync exit $?" >> "$O/summary.txt"
printf 'stable\t5.8.0\nexperimental\t5.9.0\n' | sudo tee "$D/channels.tsv" > /dev/null   # (sync-videos.zsh fetched the real ones again)
c 'for v in grumpy-cat grumpy-cat-dark bonjovi bonjovi-dark; do /bin/ls -la "$(wv_video_path $v)"; done' >> "$O/summary.txt" 2>&1
c 'for b in grumpy-cat bonjovi raccoon; do print -r -- "$b: $(wv_background_path $b) | $(wv_background_path $b dark) | video: $(wv_has_video $b && print yes || print no) | style: $(wv_greeting_style "$(wv_video_path $b)")"; done' >> "$O/summary.txt" 2>&1

log "adding pictures"
for f in sideways-exif6.jpg portrait-clear.png tiny.png not-a-picture.jpg sideways-exif6.jpg; do
  r="$(zsh "$D/settings.zsh" --own-add "$PWD/ci/own/$f" 2>&1)"; echo "$f -> '$r' (exit $?)" >> "$O/summary.txt"
done
ls -la "$OWN" >> "$O/summary.txt" 2>&1
for p in "$OWN"/own-*.jpg; do
  cp "$p" "$O/pictures/"
  sips -g pixelWidth -g pixelHeight -g format "$p" >> "$O/summary.txt" 2>&1
done
c 'print -r -- "pictures: $(wv_own_pictures | tr "\n" " ")"' >> "$O/summary.txt" 2>&1

log "using one"
first="$(c 'wv_own_pictures | head -1')"
zsh "$D/settings.zsh" --save Background "$first" >> "$O/summary.txt" 2>&1; echo "save exit $?" >> "$O/summary.txt"
zsh "$D/settings.zsh" --apply >> "$O/summary.txt" 2>&1; echo "apply exit $?" >> "$O/summary.txt"; sleep 3
c 'print -r -- "Background=$(wv_setting Background) current=$(wv_current_background) path=$(wv_background_path $(wv_current_background)) video=$(wv_video_file 2>/dev/null)"' >> "$O/summary.txt" 2>&1
osascript -e 'tell application "System Events" to get picture of every desktop' >> "$O/summary.txt" 2>&1
screencapture -x "$O/desktop-own.png"
log "the guard keeps it (and reports 'own', never the picture)"
sleep 25
osascript -e 'tell application "System Events" to get picture of every desktop' >> "$O/summary.txt" 2>&1
sudo grep -h "own" /Library/Logs/ca.schoolathome.welcomevideo.log 2>/dev/null | tail -5 >> "$O/summary.txt"
sudo zsh -c 'source "$1/common.zsh"; for f in "$1"/Care/*(N.); do print -r -- "${f:t}: $(head -c 300 "$f" | tr "\n" " ")"; done' t "$D" >> "$O/summary.txt" 2>&1

log "filling a tile (debug)"
for p in "$OWN"/own-*.jpg; do osascript -l JavaScript ci/fill-debug.js "$p" "$O/fill-${p:t:r}.png" >> "$O/summary.txt" 2>&1; done
log "pictures of the app"
TB_TEST="$O/app" zsh "$D/settings.zsh" > "$O/app/result.txt" 2>&1; echo "self-test exit $?" >> "$O/summary.txt"

log "removing the one in use"
zsh "$D/settings.zsh" --own-remove "$first" >> "$O/summary.txt" 2>&1; echo "remove exit $?" >> "$O/summary.txt"; sleep 4
c 'print -r -- "Background=$(wv_setting Background) (saved: $(wv_get Background)) current=$(wv_current_background) pictures: $(wv_own_pictures | tr "\n" " ")"' >> "$O/summary.txt" 2>&1
osascript -e 'tell application "System Events" to get picture of every desktop' >> "$O/summary.txt" 2>&1

log "at most 12"
for i in $(seq 1 12); do
  sips -s format png -z $((300 + i)) $((500 + i)) "$PWD/ci/own/portrait-clear.png" --out "/tmp/p$i.png" > /dev/null 2>&1
  r="$(zsh "$D/settings.zsh" --own-add "/tmp/p$i.png" 2>&1)"; echo "p$i -> '$r' (exit $?)" >> "$O/summary.txt"
done
c 'print -r -- "count: $(wv_own_pictures | wc -l)"' >> "$O/summary.txt" 2>&1

log "on a Mac that's TLA's (the guard's note says dep)"
echo dep | sudo tee "$D/Care/enrollment" > /dev/null
c 'print -r -- "own allowed=$(wv_own_allowed && print yes || print no) current=$(wv_current_background)"' >> "$O/summary.txt" 2>&1
r="$(zsh "$D/settings.zsh" --own-add "$PWD/ci/own/sideways-exif6.jpg" 2>&1)"; echo "add -> '$r' (exit $?)" >> "$O/summary.txt"
mkdir -p "$O/tla-mac"; TB_TEST="$O/tla-mac" zsh "$D/settings.zsh" > "$O/tla-mac/result.txt" 2>&1
echo none | sudo tee "$D/Care/enrollment" > /dev/null

cp ~/Library/Logs/"TLA BootPaper.log" "$O/log.txt" 2>/dev/null
sudo tail -40 /Library/Logs/ca.schoolathome.welcomevideo.log > "$O/guard-log.txt" 2>&1
