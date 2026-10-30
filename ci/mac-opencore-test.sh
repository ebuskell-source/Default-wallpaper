#!/bin/bash
# 7.5.0 on an Intel Mac in the cloud: what TLA Care offers each kind of Mac (pretending to be it), the two windows
# someone sees before choosing, the start of the real thing as root (OCLP downloaded, checked, installed, and OpenCore
# built for a 2012 MacBook Pro; not put on the disk, and no restart), and the sign-out lock.
set -u
O="$PWD/out/oc"; mkdir -p "$O/shots"
D="/Library/Application Support/ca.schoolathome.welcomevideo"
log() { echo "== $*" >> "$O/summary.txt"; }
{ sw_vers | tr '\n' ' '; uname -m; sysctl -n hw.model; } >> "$O/summary.txt"
sudo installer -pkg ci/test.pkg -target / > "$O/install.txt" 2>&1; echo "installer: $?" >> "$O/summary.txt"
launchctl bootout "gui/$(id -u)/ca.schoolathome.welcomevideo.lock" 2>/dev/null
sleep 10; sudo launchctl bootout system/ca.schoolathome.welcomevideo.guard 2>/dev/null
printf 'stable\t6.5.0\nexperimental\t7.5.0\n' | sudo tee "$D/channels.tsv" > /dev/null
defaults write ca.schoolathome.welcomevideo Channel experimental
sudo launchctl print system/ca.schoolathome.welcomevideo.opencore 2>&1 | grep -E "state =|run interval|last exit" >> "$O/summary.txt"

log "offers (pretending to be each Mac)"
for m in MacBookPro9,2 MacBookPro8,1 MacBook5,1 iMac14,2 MacPro6,1 MacBookPro14,3 MacBookAir7,2 iMac19,1 MacBookAir8,1 MacBookPro16,1; do
  macos=12; [[ "$m" == iMac19,1 ]] && macos=15
  echo "-- $m (on macOS $macos)" >> "$O/summary.txt"
  TB_TEST_MODEL=$m TB_TEST_MACOS=$macos zsh "$D/settings.zsh" --opencore | grep -E '^(model|offer|issue)' >> "$O/summary.txt"
done
echo "-- the stable channel (nothing offered):" >> "$O/summary.txt"
defaults write ca.schoolathome.welcomevideo Channel stable
TB_TEST_MODEL=MacBookPro9,2 TB_TEST_MACOS=12 zsh "$D/settings.zsh" --opencore | grep '^offer' >> "$O/summary.txt"
defaults write ca.schoolathome.welcomevideo Channel experimental

log "TLA Care, as a 2012 MacBook Pro"
export TB_TEST_MODEL=MacBookPro9,2 TB_TEST_MACOS=12
TB_TEST_MODEL=MacBookPro9,2 TB_TEST_MACOS=12 zsh -c 'source "$1/common.zsh"; wv_care_checks' t "$D" | grep opencore >> "$O/summary.txt"
zsh "$D/settings.zsh" --care > /dev/null 2>&1 &
sleep 12; screencapture -x -t jpg "$O/shots/1-care.jpg"
pid="$(pgrep -f 'care-app\.js' | head -1)"
osascript -e "tell application \"System Events\" to tell (first process whose unix id is $pid) to click button \"See what changes\" of window 1" >> "$O/summary.txt" 2>&1
sleep 3; screencapture -x -t jpg "$O/shots/2-choose.jpg"
osascript -e "tell application \"System Events\" to tell (first process whose unix id is $pid) to get name of every button of window 1" >> "$O/summary.txt" 2>&1
osascript -e "tell application \"System Events\" to tell (first process whose unix id is $pid) to click button \"macOS Sequoia (recommended)\" of window 1" >> "$O/summary.txt" 2>&1
sleep 3; screencapture -x -t jpg "$O/shots/3-sequoia-changes.jpg"
osascript -e "tell application \"System Events\" to tell (first process whose unix id is $pid) to click button \"Cancel\" of window 1" >> "$O/summary.txt" 2>&1
sleep 2
osascript -e "tell application \"System Events\" to tell (first process whose unix id is $pid) to click button \"See what changes\" of window 1" >> /dev/null 2>&1
sleep 3; osascript -e "tell application \"System Events\" to tell (first process whose unix id is $pid) to click button \"macOS Tahoe (OpenCore Legacy Patcher 3.0.0-rc.5)\" of window 1" >> "$O/summary.txt" 2>&1
sleep 3; screencapture -x -t jpg "$O/shots/4-tahoe-changes.jpg"
osascript -e "tell application \"System Events\" to tell (first process whose unix id is $pid) to click button \"Cancel\" of window 1" >> /dev/null 2>&1
pkill -f 'care-app\.js'
unset TB_TEST_MODEL TB_TEST_MACOS

log "as root, the first stage (test: OpenCore built for MacBookPro9,2, not put on the disk)"
sudo zsh -c 'source "$1/common.zsh"; source "$1/opencore.zsh"; OC_ROOT=1; rm -f "$OC_STATE"; oc_set target sequoia oclp 2.5.1 user test; oc_phase prepare "test"' t "$D"
time sudo env TB_TEST=1 TB_TEST_MODEL=MacBookPro9,2 TB_TEST_MACOS=12 zsh "$D/opencore.zsh" run >> "$O/summary.txt" 2>&1; echo "run exit $?" >> "$O/summary.txt"
cat "$D/Care/opencore" >> "$O/summary.txt"
b="$(sudo grep '^built=' "$D/Care/opencore" | cut -d= -f2-)"; ls "$b" "$b/EFI/OC" 2>&1 | head -20 >> "$O/summary.txt"
defaults read "/Library/Application Support/Dortania/OpenCore-Patcher.app/Contents/Info.plist" CFBundleShortVersionString >> "$O/summary.txt" 2>&1
log "EFI partition it would use (read only)"; sudo zsh -c 'source "$1/opencore.zsh"; oc_efi_partition' t "$D" >> "$O/summary.txt" 2>&1; diskutil list >> "$O/disks.txt"
log "Apple's installers list (parsing only)"; softwareupdate --list-full-installers 2>&1 | head -8 >> "$O/summary.txt"
log "sign-out locks straight away (TLA's Mac)"
pip3 install --quiet --break-system-packages cryptography > /dev/null 2>&1 || pip3 install --quiet cryptography > /dev/null 2>&1
python3 ci/signin/prep.py /tmp/signin-test > /dev/null 2>&1
sudo mkdir -p "$D/SignIn"; sudo cp /tmp/signin-test/auth.json /tmp/signin-test/keys.json "$D/SignIn/"; sudo touch "$D/.signin-checked"
U="$(ioreg -rd1 -c IOPlatformExpertDevice | sed -n 's/.*"IOPlatformUUID" = "\(.*\)".*/\1/p')"; n="$(python3 ci/signin/mktoken.py nonce "mac:$U" "$(id -un)" c2FsdHNhbHRzYWx0c2FsdA)"
defaults write ca.schoolathome.welcomevideo SignInToken "$(python3 ci/signin/mktoken.py token hub $(date +%s) "$n")"; defaults write ca.schoolathome.welcomevideo SignInSalt c2FsdHNhbHRzYWx0c2FsdA
echo dep | sudo tee "$D/Care/enrollment" > /dev/null
launchctl bootstrap "gui/$(id -u)" /Library/LaunchAgents/ca.schoolathome.welcomevideo.lock.plist; sleep 8
echo "before: $(pgrep -f 'lock-app\.js' | wc -l | tr -d ' ') lock screens, $(zsh "$D/settings.zsh" --signin status | cut -f1)" >> "$O/summary.txt"
zsh "$D/settings.zsh" --signin out; t0=$(date +%s)
for i in $(seq 1 30); do pgrep -f 'lock-app\.js' > /dev/null && break; sleep 1; done
echo "after signing out: $(pgrep -f 'lock-app\.js' | wc -l | tr -d ' ') lock screens after $(( $(date +%s) - t0 ))s" >> "$O/summary.txt"
sleep 2; screencapture -x -t jpg "$O/shots/5-signed-out.jpg"
log "log"; grep -i opencore /Library/Logs/ca.schoolathome.welcomevideo.log | tail -20 >> "$O/summary.txt"
echo done >> "$O/summary.txt"
