#!/bin/bash
# Installs the test package, then takes pictures of the TLA BootPaper app (its own self-test) and plays a video
# through settings.zsh --play (the whole path: common.zsh picks the greeting style, tla-player draws it).
set -u
mkdir -p out/app
D="/Library/Application Support/ca.schoolathome.welcomevideo"
sudo installer -pkg ci/test.pkg -target / > out/app/install.txt 2>&1; echo "installer: $?" >> out/app/install.txt
defaults write ca.schoolathome.welcomevideo Channel experimental
defaults write ca.schoolathome.welcomevideo PreferredName Sevilen
sleep 5
TB_TEST="$PWD/out/app" zsh "$D/settings.zsh" > out/app/result.txt 2>&1; echo "exit $?" >> out/app/result.txt
zsh "$D/settings.zsh" --state > out/app/state.txt 2>&1
# Light mode first, as installed; then the same in dark mode (a new process picks it up)
defaults write -g AppleInterfaceStyle Dark
mkdir -p out/app-dark
TB_TEST="$PWD/out/app-dark" zsh "$D/settings.zsh" > out/app-dark/result.txt 2>&1
defaults delete -g AppleInterfaceStyle
# Playing through the app's "Play" path, with the greeting
curl -sfL -o v.mp4 https://raw.githubusercontent.com/ebuskell-source/Default-wallpaper/main/TLA-BootPaper/videos/pixel.mp4
sudo mkdir -p "$D/Videos"; sudo cp v.mp4 "$D/Videos/pixel.mp4"
start=$(python3 -c 'import time;print(time.time())')
zsh "$D/settings.zsh" --play pixel > out/app/play.txt 2>&1 &
pid=$!
for t in 1.5 2.5 4.0; do python3 -c "import time; d=$start+$t-time.time(); time.sleep(d if d>0 else 0)"; screencapture -x -t jpg "out/app/play-$t.jpg"; done
sleep 4; kill $pid 2>/dev/null; pkill -f tla-player
cp ~/Library/Logs/"TLA BootPaper.log" out/app/log.txt 2>/dev/null
ls -la "$D" > out/app/files.txt
