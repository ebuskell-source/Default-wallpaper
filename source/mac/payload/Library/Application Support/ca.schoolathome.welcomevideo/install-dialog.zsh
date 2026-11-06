#!/bin/zsh
# install-dialog.zsh - runs as root. Installs swiftDialog (which shows the video, the app and the release log)
# if it's missing. Called by the package's postinstall and, until it works, by guard.zsh every 15 minutes,
# so a Mac that was offline or couldn't reach GitHub during the install catches up on its own.
# Only installs a package signed by swiftDialog's developer (Team ID PWA5E9TQ59).

DIALOG_BIN="/usr/local/bin/dialog"
TEAM_ID="PWA5E9TQ59"                       # Bart Reardon (swiftDialog developer)
LOG_FILE="/Library/Logs/ca.schoolathome.welcomevideo.log"
log() { print -r -- "$(/bin/date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG_FILE"; }

[[ -x "$DIALOG_BIN" ]] && exit 0
log "swiftDialog missing; installing it"

# The download link for the newest release. The GitHub API is tried first; it allows only 60 requests an
# hour per network address, which a school network can use up, so the release page itself is the fallback.
# 7.2.0: swiftDialog 3 needs macOS 15, so older macOS gets v2.5.6, its makers' last release for macOS 12 to 14.
major="$(/usr/bin/sw_vers -productVersion | /usr/bin/cut -d. -f1)"
if (( major < 15 )); then
  url=""; tag="v2.5.6"
else
url=$(/usr/bin/curl -fsSL --connect-timeout 10 --max-time 30 \
        "https://api.github.com/repos/swiftDialog/swiftDialog/releases/latest" 2>/dev/null \
      | /usr/bin/awk -F '"' '/browser_download_url/ && /\.pkg"/ { print $4; exit }')
fi
if [[ "$url" != https://github.com/* ]]; then
  [[ -n "$tag" ]] || tag=$(/usr/bin/curl -fsSIL --connect-timeout 10 --max-time 30 -o /dev/null -w '%{url_effective}' \
          "https://github.com/swiftDialog/swiftDialog/releases/latest" 2>/dev/null | /usr/bin/awk -F/ '{ print $NF }')
  [[ -n "$tag" && "$tag" != latest ]] && url=$(/usr/bin/curl -fsSL --connect-timeout 10 --max-time 30 \
          "https://github.com/swiftDialog/swiftDialog/releases/expanded_assets/$tag" 2>/dev/null \
        | /usr/bin/grep -oE 'href="/swiftDialog/swiftDialog/releases/download/[^"]+\.pkg"' | /usr/bin/head -1 \
        | /usr/bin/sed -E 's#^href="#https://github.com#; s#"$##')
fi
[[ "$url" == https://github.com/* ]] || { log "ERROR: couldn't find the swiftDialog download (no internet, or GitHub unreachable)"; exit 1; }

tmp=$(/usr/bin/mktemp -d /private/tmp/swiftdialog.XXXXXX)
trap '/bin/rm -rf "$tmp"' EXIT
/usr/bin/curl -fsSL --connect-timeout 10 --max-time 300 "$url" -o "$tmp/Dialog.pkg" || { log "ERROR: swiftDialog download failed ($url)"; exit 1; }
team=$(/usr/sbin/spctl -a -vv -t install "$tmp/Dialog.pkg" 2>&1 | /usr/bin/awk '/origin=/ { print $NF }' | /usr/bin/tr -d '()')
[[ "$team" == "$TEAM_ID" ]] || { log "ERROR: swiftDialog signature check failed (Team ID '$team')"; exit 1; }
/usr/sbin/installer -pkg "$tmp/Dialog.pkg" -target / >/dev/null 2>&1 || { log "ERROR: swiftDialog install failed"; exit 1; }
log "swiftDialog installed ($("$DIALOG_BIN" --version 2>/dev/null))"
exit 0
