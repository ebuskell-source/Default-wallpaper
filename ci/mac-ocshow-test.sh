#!/bin/bash
# What TLA Care shows on an older Intel Mac that can get Sequoia (pretending to be a 2015 MacBook Air on Monterey).
set -u
O="$PWD/out/ocshow"; mkdir -p "$O"; D="/Library/Application Support/ca.schoolathome.welcomevideo"
sudo installer -pkg ci/test.pkg -target / > /dev/null 2>&1; sleep 10
defaults write ca.schoolathome.welcomevideo Channel experimental
sudo defaults write /Library/Preferences/ca.schoolathome.welcomevideo Channel experimental 2>/dev/null
export TB_TEST_MODEL=MacBookAir7,2 TB_TEST_MACOS=12
zsh "$D/settings.zsh" --opencore > "$O/opencore.txt" 2>&1
zsh "$D/settings.zsh" --care-checks > "$O/checks.txt" 2>&1
( zsh "$D/settings.zsh" --care > /dev/null 2>&1 & ); sleep 12; screencapture -x "$O/1-care.png"
osascript -e 'tell application "System Events" to click (first button whose name is "See what changes") of window "TLA Care" of (first process whose frontmost is true)' >> "$O/log.txt" 2>&1
osascript -e 'tell application "System Events" to repeat with p in (every process) 
 try
  click button "See what changes" of window "TLA Care" of p
 end try
end repeat' >> "$O/log.txt" 2>&1
sleep 4; screencapture -x "$O/2-choose.png"
osascript -e 'tell application "System Events" to key code 36' >> "$O/log.txt" 2>&1
sleep 4; screencapture -x "$O/3-changes.png"
echo done >> "$O/log.txt"
