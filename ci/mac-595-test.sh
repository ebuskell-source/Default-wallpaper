#!/bin/bash
# 5.9.5: Check for updates on every Mac: what it says when it's up to date, and an update followed start to finish in
# the app. To have something to update to, the installed copy is made to look like 5.8.0, so the version GitHub has
# (mac/latest.json) is newer and gets installed.
set -u
O="$PWD/out/m595"; mkdir -p "$O/app"
D="/Library/Application Support/ca.schoolathome.welcomevideo"
LOG=/Library/Logs/ca.schoolathome.welcomevideo.log
log() { echo "== $*" >> "$O/summary.txt"; }
sudo installer -pkg ci/test.pkg -target / > "$O/install.txt" 2>&1; echo "installer: $?" >> "$O/install.txt"
defaults write ca.schoolathome.welcomevideo PreferredName Sevilen
for i in $(seq 1 90); do
  sudo grep -q 'Release channels:' $LOG 2>/dev/null && sudo grep -q 'Sign-in settings:' $LOG 2>/dev/null && break
  sleep 2
done
sleep 5
ask() {
  local at r i
  at="$(zsh "$D/settings.zsh" --care-fix update)"
  for i in $(seq 1 30); do r="$(zsh "$D/settings.zsh" --care-result update "$at")"; [[ -n "$r" ]] && break; sleep 3; done
  echo "answer after about $((i * 3))s: $r" >> "$O/summary.txt"
  echo "Care/update: $(cat "$D/Care/update" 2>/dev/null || echo '(none)')" >> "$O/summary.txt"
}
log "installed $(awk -F'"' '/^WV_RELEASE=/ { print $2 }' "$D/common.zsh"); GitHub has $(curl -fsSL https://raw.githubusercontent.com/ebuskell-source/Default-wallpaper/main/TLA-BootPaper/mac/latest.json | plutil -extract version raw -o - -)"
log "Check for updates when it's up to date"
ask
log "made to look like 5.8.0"
sudo sed -i '' 's/^WV_RELEASE="5.9.5"/WV_RELEASE="5.8.0"/' "$D/common.zsh"
grep '^WV_RELEASE=' "$D/common.zsh" >> "$O/summary.txt"
log "the app: Check for updates, start to finish"
TB_TEST="$O/app" TB_TEST_UPDATE=1 zsh "$D/settings.zsh" > "$O/app/result.txt" 2>&1; echo "self-test exit $?" >> "$O/summary.txt"
cat "$O/app/update-texts.txt" >> "$O/summary.txt" 2>&1
log "after"
grep '^WV_RELEASE=' "$D/common.zsh" >> "$O/summary.txt"
echo "Care/update: $(cat "$D/Care/update" 2>/dev/null)" >> "$O/summary.txt"
sudo grep -h "Check for updates\|TLA BootPaper .* is out\|Updated to\|Installing TLA BootPaper\|download" $LOG | tail -10 >> "$O/summary.txt"
sudo tail -40 $LOG > "$O/guard-log.txt" 2>&1
