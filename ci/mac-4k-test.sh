#!/bin/bash
# 5.9.5: Microsoft and Liquid Glass in 4K: the files, and the desktop picture in light and dark.
set -u
O="$PWD/out/m4k"; mkdir -p "$O"
D="/Library/Application Support/ca.schoolathome.welcomevideo"
LOG=/Library/Logs/ca.schoolathome.welcomevideo.log
sudo installer -pkg ci/test.pkg -target / > "$O/install.txt" 2>&1; echo "installer: $?" >> "$O/install.txt"
for i in $(seq 1 90); do sudo grep -q 'Release channels:' $LOG 2>/dev/null && break; sleep 2; done; sleep 5
ls -la "$D/Backgrounds" | grep -i "microsoft\|liquid" > "$O/summary.txt"
for f in "$D"/Backgrounds/*-r6.jpg; do sips -g pixelWidth -g pixelHeight "$f" | tr '\n' ' ' >> "$O/summary.txt"; echo >> "$O/summary.txt"; done
for b in microsoft liquid-glass; do
  for look in Light Dark; do
    defaults write ca.schoolathome.welcomevideo Background "$b"; defaults write ca.schoolathome.welcomevideo LightDark "$look"
    zsh "$D/settings.zsh" --apply >/dev/null 2>&1; sleep 4
    echo "$b $look: $(osascript -e 'tell application "System Events" to get picture of every desktop' 2>&1)" >> "$O/summary.txt"
    screencapture -x "$O/desktop-$b-$look.png"
  done
done
zsh -c 'source "$1/common.zsh"; print -r -- "signed out: $(wv_signed_out && print yes || print no)"' t "$D" >> "$O/summary.txt"
sudo tail -15 $LOG > "$O/guard-log.txt"
