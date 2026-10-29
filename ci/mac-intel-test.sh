#!/bin/bash
# An Intel Mac: does TLA BootPaper 6.3.5 run there? The package, the app window, the tour, the player, and why not.
set -u
O="$PWD/out/intel"; mkdir -p "$O/app" "$O/tour"
D="/Library/Application Support/ca.schoolathome.welcomevideo"; A="/Applications/TLA BootPaper.app"
log() { echo "== $*" >> "$O/summary.txt"; }
{ sw_vers; uname -m; sysctl -n machdep.cpu.brand_string; sysctl -n machdep.cpu.features | tr ' ' '\n' | grep -E '^(AVX1.0|SSE4.2)$' | tr '\n' ' '; sysctl -n machdep.cpu.leaf7_features | tr ' ' '\n' | grep -E '^(AVX2|BMI2)$' | tr '\n' ' '; echo; } >> "$O/summary.txt"
sudo installer -pkg ci/test.pkg -target / > "$O/install.txt" 2>&1; echo "installer: $?" >> "$O/summary.txt"
sleep 15
log "binaries"; for b in "$A/Contents/MacOS/welcome-video" "$D/tla-player" "$D/tla-signin"; do file "$b" | sed 's/^.*: //' >> "$O/summary.txt"; done
log "launcher runs?"; "$A/Contents/MacOS/welcome-video" --version >> "$O/summary.txt" 2>&1; echo "exit $?" >> "$O/summary.txt"
log "app window self-test (in the app)"; TB_TEST="$O/app" zsh "$D/settings.zsh" > "$O/app/result.txt" 2>&1; echo "exit $?" >> "$O/summary.txt"; head -c 600 "$O/app/result.txt" >> "$O/summary.txt"; echo >> "$O/summary.txt"; ls "$O/app" >> "$O/summary.txt"
log "the app, opened normally"; open -a "$A"; sleep 8; screencapture -x -t jpg "$O/opened.jpg"
pgrep -fl welcome-video >> "$O/summary.txt"; osascript -e 'tell application "System Events" to get name of every window of every process whose name contains "welcome"' >> "$O/summary.txt" 2>&1
log "tour self-test"; TB_TEST="$O/tour" "$A/Contents/MacOS/welcome-video" --jxa "$D/tour-app.js" "$D/settings.zsh" app > "$O/tour/result.txt" 2>&1; echo "exit $?" >> "$O/summary.txt"; ls "$O/tour" | head -3 >> "$O/summary.txt"
log "player"; "$D/tla-player" --help >> "$O/summary.txt" 2>&1; echo "exit $?" >> "$O/summary.txt"
log "BootPaper log"; tail -40 /Library/Logs/ca.schoolathome.welcomevideo.log >> "$O/summary.txt" 2>&1
log "crashes"; ls ~/Library/Logs/DiagnosticReports /Library/Logs/DiagnosticReports 2>/dev/null | grep -iE "welcome|tla|osascript" >> "$O/summary.txt"
cp ~/Library/Logs/DiagnosticReports/*welcome* ~/Library/Logs/DiagnosticReports/*tla* "$O/" 2>/dev/null
log show --last 10m --predicate 'process == "welcome-video" OR process == "tla-player"' --style compact 2>/dev/null | tail -60 > "$O/syslog.txt"
echo done >> "$O/summary.txt"
