#!/bin/zsh
# update.zsh - runs as root every 15 minutes (LaunchDaemon ca.schoolathome.welcomevideo.update).
#   1. The announcement, from TLA-BootPaper/mac/announcement.txt in the organization's GitHub repository: shown in
#      the TLA BootPaper app, and on the login window unless something else has set a login window message. Only on
#      Macs Intune doesn't manage: Intune shows the announcement on the others.
#   2. New versions of TLA BootPaper, from TLA-BootPaper/mac/latest.json ({"version", "url", "sha256"}), checked
#      every 6 hours (and straight away when someone clicks Check for updates). The package is installed only if
#      it's newer than this one, comes from the organization's repository and matches its SHA-256. 5.9.5: on every
#      Mac, Intune or not (until then, Macs Intune manages waited for Intune). Intune's copy of TLA BootPaper should
#      have "Ignore app version" on, as Microsoft advises for apps that update themselves, so it doesn't put an older
#      version back. What happens is noted in Care/update for the app's Check for updates:
#      "<starting|installing|done|failed>\t<version>\t<time>\t<why it failed>" (guard.zsh notes "starting").
#      6.1.0: and how far it's got, for the app's progress bar: a fifth field, "download <percent>" (latest.json gives
#      the package's size) or "install <percent>" (from the installer).
# It has a service of its own (not guard.zsh) because installing restarts the guard, which would stop the install.

WV_DIR="/Library/Application Support/ca.schoolathome.welcomevideo"
REPO="https://raw.githubusercontent.com/ebuskell-source/Default-wallpaper/main/TLA-BootPaper/mac"
LOG_FILE="/Library/Logs/ca.schoolathome.welcomevideo.log"
LOGINWINDOW="/Library/Preferences/com.apple.loginwindow"
log() { print -r -- "$(/bin/date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG_FILE"; }
sha() { /usr/bin/shasum -a 256 "$1" 2>/dev/null | /usr/bin/awk '{ print $1 }' }
vkey() { local -a p=(${(s:.:)1} 0 0 0 0); printf '%04d%04d%04d%04d' $(( 10#${p[1]} )) $(( 10#${p[2]} )) $(( 10#${p[3]} )) $(( 10#${p[4]} )) }

# Takes the login window message back off (only if it's still the one this set).
clear_ours() {
  local ours; ours="$(/bin/cat "$WV_DIR/.loginwindow-text" 2>/dev/null)"
  if [[ -n "$ours" && "$(/usr/bin/defaults read "$LOGINWINDOW" LoginwindowText 2>/dev/null)" == "$ours" ]]; then
    /usr/bin/defaults delete "$LOGINWINDOW" LoginwindowText 2>/dev/null
  fi
  /bin/rm -f "$WV_DIR/.loginwindow-text" "$WV_DIR/announcement.txt"
}

# Managed by Intune (or another MDM)? Then Intune shows the announcement (5.9.5: updates come from here either way). 5.2.5: noted in Care/mdm for "Connect to TLA" in
# the TLA BootPaper app (only when profiles says either way: nothing changes if it can't tell).
enrollment="$(/usr/bin/profiles status -type enrollment 2>/dev/null)"
managed=""
[[ "$enrollment" == *"MDM enrollment: Yes"* ]] && managed=yes
[[ "$enrollment" == *"MDM enrollment: No"* ]] && managed=no
if [[ -n "$managed" && "$(/bin/cat "$WV_DIR/Care/mdm" 2>/dev/null)" != "enrolled=$managed" ]]; then
  /bin/mkdir -p "$WV_DIR/Care" && print -r -- "enrolled=$managed" > "$WV_DIR/Care/mdm" && /bin/chmod 644 "$WV_DIR/Care/mdm"
  log "Managed by Intune: $managed."
fi
if [[ "$managed" == yes ]]; then
  [[ -f "$WV_DIR/announcement.txt" || -f "$WV_DIR/.loginwindow-text" ]] && { clear_ours; log "This Mac is managed now: the GitHub announcement is off."; }
fi

# ---- 1. The announcement ----------------------------------------------------------------------------------
# Comment lines (starting with #) and blank lines dropped, at most 300 characters, printable characters only.
rc=1
if [[ "$managed" != yes ]]; then
  raw="$(/usr/bin/curl -fsSL --connect-timeout 10 --max-time 30 "$REPO/announcement.txt" 2>/dev/null)"
  rc=$?
fi
if [[ "$managed" == yes ]]; then
  :   # (Intune shows it)
elif (( rc == 0 )); then
  text=""
  for line in "${(@f)raw}"; do
    line="${line//$'\r'/}"
    line="${line#"${line%%[![:space:]]*}"}"; line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    text+="${text:+ }$line"
  done
  text="${text//[[:cntrl:]]/}"; text="${text[1,300]}"
  if [[ "$text" != "$(/bin/cat "$WV_DIR/announcement.txt" 2>/dev/null)" ]]; then
    if [[ -n "$text" ]]; then
      print -r -- "$text" > "$WV_DIR/.announcement.$$" && /bin/chmod 644 "$WV_DIR/.announcement.$$" &&
        /bin/mv -f "$WV_DIR/.announcement.$$" "$WV_DIR/announcement.txt"
      /bin/rm -f "$WV_DIR/.announcement.$$"
      log "Announcement from GitHub: $text"
    else
      /bin/rm -f "$WV_DIR/announcement.txt"
      log "Announcement from GitHub: none."
    fi
  fi
  # The login window: only when it has no message of its own (or still shows the one this set).
  current="$(/usr/bin/defaults read "$LOGINWINDOW" LoginwindowText 2>/dev/null)"
  ours="$(/bin/cat "$WV_DIR/.loginwindow-text" 2>/dev/null)"
  if [[ -z "$current" || "$current" == "$ours" ]] && [[ "$current" != "$text" ]]; then
    if [[ -n "$text" ]]; then
      /usr/bin/defaults write "$LOGINWINDOW" LoginwindowText -string "$text" && print -r -- "$text" > "$WV_DIR/.loginwindow-text"
    else
      [[ -n "$current" ]] && /usr/bin/defaults delete "$LOGINWINDOW" LoginwindowText 2>/dev/null
      /bin/rm -f "$WV_DIR/.loginwindow-text"
    fi
  fi
elif (( rc == 22 )); then
  : # (not there: GitHub answered 404. The last announcement stays, as when offline.)
fi

# ---- 2. Updates, every 6 hours ------------------------------------------------------------------------------
stamp="$WV_DIR/.update-check"
[[ -f "$stamp" && -z "$(/usr/bin/find "$stamp" -mmin +360 2>/dev/null)" ]] && exit 0
/usr/bin/touch "$stamp"
status() {   # status <installing|done|failed> [why] [progress]   (5.9.5: for the app's Check for updates; 6.1.0: progress)
  /bin/mkdir -p "$WV_DIR/Care" &&
    print -r -- "$1	$version	$(/bin/date +%s)	${2:-}	${3:-}" > "$WV_DIR/Care/.update.$$" && /bin/chmod 644 "$WV_DIR/Care/.update.$$" &&
    /bin/mv -f "$WV_DIR/Care/.update.$$" "$WV_DIR/Care/update"
  /bin/rm -f "$WV_DIR/Care/.update.$$"
}
json="$(/usr/bin/curl -fsSL --connect-timeout 10 --max-time 30 "$REPO/latest.json" 2>/dev/null)" || exit 0
version="$(print -r -- "$json" | "/Library/Application Support/ca.schoolathome.welcomevideo/pl" version - 2>/dev/null)"
url="$(print -r -- "$json" | "/Library/Application Support/ca.schoolathome.welcomevideo/pl" url - 2>/dev/null)"
want="$(print -r -- "$json" | "/Library/Application Support/ca.schoolathome.welcomevideo/pl" sha256 - 2>/dev/null)"
size="$(print -r -- "$json" | "/Library/Application Support/ca.schoolathome.welcomevideo/pl" size - 2>/dev/null)"   # (6.1.0, for the progress bar)
# 7.0: "release", when there is one, is the version the package really is; "version" is then only what older copies of
# this script compare. (7.5.0 went out by mistake for half an hour and was renumbered 7.0: "version" stays above 7.5.0,
# e.g. 7.5.0.1, until a real release passes it, so the Macs that got 7.5.0 still take each new one, while Macs that
# already have "release" skip it.)
release="$(print -r -- "$json" | "/Library/Application Support/ca.schoolathome.welcomevideo/pl" release - 2>/dev/null)"
[[ "$release" =~ '^[0-9]{1,4}(\.[0-9]{1,4}){0,3}$' ]] || release=""
[[ "$size" == <1-> ]] || size=0
[[ "$version" =~ '^[0-9]{1,4}(\.[0-9]{1,4}){0,3}$' && "$want" =~ '^[0-9a-f]{64}$' ]] || { log "latest.json doesn't look right; no update."; exit 0; }
[[ "$url" == https://raw.githubusercontent.com/ebuskell-source/Default-wallpaper/main/TLA-BootPaper/mac/*.pkg ]] ||
  { log "latest.json points outside the TLA repository; no update."; exit 0; }
installed="$(/usr/bin/awk -F'"' '/^WV_RELEASE=/ { print $2; exit }' "$WV_DIR/common.zsh" 2>/dev/null)"
[[ -n "$installed" ]] || exit 0
if [[ -n "$release" ]]; then
  [[ "$(vkey "$release")" > "$(vkey "$installed")" || ( "$(vkey "$version")" > "$(vkey "$installed")" && "$installed" == 7.5.0 ) ]] || exit 0
  version="$release"
else
  [[ "$(vkey "$version")" > "$(vkey "$installed")" ]] || exit 0
fi

log "TLA BootPaper $version is out (this Mac has $installed): downloading it."
status installing "" "download 0"
tmp="$(/usr/bin/mktemp -d /private/tmp/tla-bootpaper-update.XXXXXX)" || { status failed "it couldn't make a folder to download it into"; exit 0; }
trap '/bin/rm -rf "$tmp"' EXIT
# 6.1.0: the download in the background, noting how much has arrived each second.
{ /usr/bin/curl -fsSL --connect-timeout 10 --max-time 600 "$url" -o "$tmp/TLA-BootPaper.pkg" 2>/dev/null; print -r -- $? > "$tmp/curl-rc"; } &
cpid=$!
while /bin/kill -0 $cpid 2>/dev/null; do
  /bin/sleep 1
  if (( size > 0 )); then
    have="$(/usr/bin/stat -f %z "$tmp/TLA-BootPaper.pkg" 2>/dev/null)"; [[ "$have" == <-> ]] || have=0
    pct=$(( have * 100 / size )); (( pct > 100 )) && pct=100
    status installing "" "download $pct"
  fi
done
wait $cpid 2>/dev/null
if [[ "$(/bin/cat "$tmp/curl-rc" 2>/dev/null)" != 0 ]]; then
  log "Couldn't download TLA BootPaper $version; trying again later."; /bin/rm -f "$stamp"
  status failed "it couldn't be downloaded. Check that this Mac is online"; exit 0
fi
if [[ "$(sha "$tmp/TLA-BootPaper.pkg")" != "$want" ]]; then
  log "The TLA BootPaper $version package doesn't match its SHA-256; not installing it."
  status failed "the download didn't match what TLA published"; exit 0
fi
status installing "" "install 0"
# 6.1.0: the installer says how far it's got ("installer:%42.5"): that goes to the progress bar, the rest to the log.
/usr/sbin/installer -pkg "$tmp/TLA-BootPaper.pkg" -target / -verboseR 2>&1 | while IFS= read -r line; do
  if [[ "$line" == installer:%* ]]; then
    pct="${${line#installer:%}%%.*}"; [[ "$pct" == <-> ]] && status installing "" "install $pct"
  elif [[ "$line" != installer:PHASE:* && "$line" != installer:STATUS:* ]]; then
    print -r -- "$line" >> "$LOG_FILE"
  fi
done
if (( ${pipestatus[1]} == 0 )); then
  log "Updated to TLA BootPaper $version."
  status done
else
  log "Installing TLA BootPaper $version didn't work; trying again in 6 hours."
  status failed "macOS couldn't install it"
fi
exit 0
