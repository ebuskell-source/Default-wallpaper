#!/bin/zsh
# screensaver-setup.zsh - runs as root (from the package's postinstall, then guard.zsh every 15 minutes until it's
# ready). The TLA screensaver (5.0): the TLA video, played by Aerial (aerialscreensaver.github.io, free and open
# source), set up the way it is on Edmund's Mac:
#   1. Aerial 4.1.7 in /Applications, if it isn't there: downloaded from Aerial's GitHub releases, and only
#      installed if the download matches its SHA-256 and is signed by Aerial's developer (Team ID 3L54M5L5KK).
#   2. The TLA video in Aerial's "My Videos" folder (/Users/Shared/Aerial/My Videos), downloaded by sync-videos.zsh.
#   3. Where Aerial hasn't been set up yet: Aerial's settings, made so it plays just the TLA video (a playlist of
#      its own), with Aerial's own downloads, update checks and on-screen extras (clock, weather) off.
# Each person's screensaver is then set to Aerial in their session (wv_update_screensaver in common.zsh).
# Aerial 4.1 needs macOS 26 or later; on older macOS this only records that.
# Writes the result to Screensaver/status: ready | needs-macos-26 | waiting: <what for> | failed: <why>.

WV_DIR="/Library/Application Support/ca.schoolathome.welcomevideo"
LOG_FILE="/Library/Logs/ca.schoolathome.welcomevideo.log"
AERIAL_URL="https://github.com/AerialScreensaver/Aerial/releases/download/v4.1.7/Aerial-4.1.7.zip"
AERIAL_SHA="25da348589b73fbcee73181e87e7a398e2152389c228f48fe364a52cd81eee51"
AERIAL_VERSION="4.1.7"
AERIAL_TEAM="3L54M5L5KK"                     # Guillaume Louel (Aerial's developer)
AERIAL_APP="/Applications/Aerial.app"
SHARED="/Users/Shared/Aerial"
VIDEO_NAME="TLA 2026 Screensaver.mov"
VIDEO_ID="5E3C2026-71A0-4B0F-9C1A-544C41323032"      # (fixed, so the playlist always finds it)
PLAYLIST_ID="71A02026-5C2E-4E5A-8A11-544C41505031"
log() { print -r -- "$(/bin/date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG_FILE"; }
vkey() { local -a p=(${(s:.:)1} 0 0 0 0); printf '%04d%04d%04d%04d' $(( 10#${p[1]} )) $(( 10#${p[2]} )) $(( 10#${p[3]} )) $(( 10#${p[4]} )) }
/bin/mkdir -p "$WV_DIR/Screensaver"
# One at a time (the install and the guard can both start it).
zmodload zsh/system 2>/dev/null
: >> "$WV_DIR/Screensaver/.lock" 2>/dev/null
zsystem flock -t 0 -f lockfd "$WV_DIR/Screensaver/.lock" 2>/dev/null || exit 75
status() {
  [[ "$(/bin/cat "$WV_DIR/Screensaver/status" 2>/dev/null)" == "$1" ]] && return 0
  print -r -- "$1" > "$WV_DIR/Screensaver/status"; /bin/chmod 644 "$WV_DIR/Screensaver/status"
  log "Screensaver: $1"
}

major="$(/usr/bin/sw_vers -productVersion 2>/dev/null)"; major="${major%%.*}"
if [[ "$major" != <-> ]] || (( major < 26 )); then status needs-macos-26; exit 0; fi

# ---- 1. Aerial ---------------------------------------------------------------------------------------------
have="$(/usr/bin/defaults read "$AERIAL_APP/Contents/Info" CFBundleShortVersionString 2>/dev/null)"
id="$(/usr/bin/defaults read "$AERIAL_APP/Contents/Info" CFBundleIdentifier 2>/dev/null)"
if [[ "$id" != com.glouel.Aerial-App || -z "$have" || "$(vkey "$have")" < "$(vkey "$AERIAL_VERSION")" ]]; then
  tmp="$(/usr/bin/mktemp -d /private/tmp/tla-aerial.XXXXXX)" || { status "failed: no temporary folder"; exit 1; }
  trap '/bin/rm -rf "$tmp"' EXIT
  if ! /usr/bin/curl -fsSL --connect-timeout 10 --max-time 600 "$AERIAL_URL" -o "$tmp/Aerial.zip" 2>/dev/null; then
    status "waiting: the Aerial download (no internet?)"; exit 1
  fi
  got="$(/usr/bin/shasum -a 256 "$tmp/Aerial.zip" | /usr/bin/awk '{ print $1 }')"
  [[ "$got" == "$AERIAL_SHA" ]] || { status "failed: the Aerial download doesn't match its SHA-256"; exit 1; }
  /usr/bin/ditto -x -k "$tmp/Aerial.zip" "$tmp/x" 2>/dev/null && [[ -d "$tmp/x/Aerial.app" ]] || { status "failed: couldn't unpack Aerial"; exit 1; }
  team="$(/usr/bin/codesign -dv "$tmp/x/Aerial.app" 2>&1 | /usr/bin/awk -F= '/^TeamIdentifier=/ { print $2 }')"
  if [[ "$team" != "$AERIAL_TEAM" ]] || ! /usr/bin/codesign --verify --deep --strict "$tmp/x/Aerial.app" 2>/dev/null; then
    status "failed: Aerial's signature doesn't check out (Team ID '$team')"; exit 1
  fi
  /usr/bin/pkill -x Aerial 2>/dev/null
  /bin/rm -rf "$AERIAL_APP"
  /usr/bin/ditto "$tmp/x/Aerial.app" "$AERIAL_APP" || { status "failed: couldn't copy Aerial to Applications"; exit 1; }
  /usr/sbin/chown -R root:wheel "$AERIAL_APP"; /bin/chmod -R go-w "$AERIAL_APP"
  /usr/bin/xattr -dr com.apple.quarantine "$AERIAL_APP" 2>/dev/null
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$AERIAL_APP" 2>/dev/null
  log "Installed Aerial $AERIAL_VERSION${have:+ (was $have)}."
fi

# ---- 2. The TLA video ----------------------------------------------------------------------------------------
src="$WV_DIR/Screensaver/$VIDEO_NAME"
[[ -f "$src" ]] || { status "waiting: the screensaver video (it downloads with the intro videos)"; exit 1; }

# A JSON file, written only if it isn't there yet (keep=1) or always (keep=0).
put() {   # put <keep> <file> <text>
  [[ "$1" == 1 && -f "$2" ]] && return 0
  /bin/mkdir -p "${2:h}"
  print -r -- "$3" > "$2.$$.tmp" && /bin/mv -f "$2.$$.tmp" "$2"
  /bin/rm -f "$2.$$.tmp"
}

new=0; [[ -f "$SHARED/companion.json" ]] || new=1
ours=0; [[ -f "$SHARED/.tla-bootpaper" ]] && ours=1
/bin/mkdir -p "$SHARED/My Videos" "$SHARED/Cache" "$SHARED/Logs" "$SHARED/Playlists" "$SHARED/Sources/My Videos"
if ! /usr/bin/cmp -s "$src" "$SHARED/My Videos/$VIDEO_NAME"; then
  /bin/cp -f "$src" "$SHARED/My Videos/.$VIDEO_NAME.$$.tmp" && /bin/mv -f "$SHARED/My Videos/.$VIDEO_NAME.$$.tmp" "$SHARED/My Videos/$VIDEO_NAME"
  /bin/rm -f "$SHARED/My Videos/.$VIDEO_NAME.$$.tmp"
  log "Put the TLA video in Aerial's My Videos."
fi
# Where TLA BootPaper set Aerial up, the video and its folder stay root's (everyone can play it; nobody can swap it
# for everyone else). Someone's own Aerial setup is left as it is (just the video added).
if (( new || ours )); then
  /usr/sbin/chown root:wheel "$SHARED/My Videos" "$SHARED/My Videos/$VIDEO_NAME"
  /bin/chmod 755 "$SHARED/My Videos"; /bin/chmod 644 "$SHARED/My Videos/$VIDEO_NAME"
else
  /bin/chmod a+r "$SHARED/My Videos/$VIDEO_NAME" 2>/dev/null
fi

# ---- 3. Aerial's settings, where Aerial hasn't been set up (or TLA BootPaper set it up) ----------------------
if (( new || ours )); then
  k=$(( ours ))   # (first time: write everything; afterwards: only put back what's missing)
  put $k "$SHARED/companion.json" '{
  "appPresentationChosen" : true, "cleanWallpaperCache" : true, "debugMode" : false,
  "desktopAutoAdvance" : false, "desktopAutoAdvanceMinutes" : 60, "desktopAutoPause" : true,
  "desktopAutoPauseIgnoredApps" : [ ], "desktopAutoPauseThreshold" : 0.6, "desktopPauseOnBattery" : false,
  "desktopPauseOnBatteryMode" : "anyBattery", "desktopPauseOnCamera" : false, "desktopPauseOnLowPower" : false,
  "desktopPauseOnThermal" : true, "dismissedNewBadges" : [ "myVideos" ], "enabledNowPlayingSources" : [ ],
  "firstLaunchCompleted" : true, "firstTimeSetup" : false, "globalShortcutsEnabled" : false, "globalSpeed" : 0,
  "intAppPresentation" : 0, "intLaunchMode" : 0, "intWallpaperMode" : 0, "invertColors" : false,
  "lastLaunchedVersion" : "4.1.7", "playlistCycleMode" : 0, "playlistListMode" : true, "playlistShuffle" : false,
  "popoverSolidBackground" : false, "reclaimMacOSWallpaperVideosAtStartup" : false,
  "showRestartWallpaperButton" : false, "wallpaperModeChosen" : true
}'
  put $k "$SHARED/screensaver.json" '{
  "advanced" : { "ciOverrideLanguage" : "", "debugMode" : false, "favorOrientation" : true, "intOverlapWorkaround" : 4,
    "muteGlobalSound" : false, "muteSound" : true, "newDisplayDict" : { }, "showDiagnosticBadges" : false },
  "cache" : { "allowedNetworks" : [ ], "cacheLimit" : 5, "enableManagement" : false, "expansionsAtCacheLocation" : false,
    "intCachePeriodicity" : 1, "lastRotationRun" : 0, "overrideCache" : false, "restrictOnWiFi" : false,
    "unlimitedCache" : false },
  "displays" : { "advancedMargins" : "", "displayMarginsAdvanced" : false, "horizontalMargin" : 0, "intAspectMode" : 0,
    "intDisplayMode" : 0, "intViewingMode" : 1, "verticalMargin" : 0 },
  "displaysDesktop" : { "advancedMargins" : "", "displayMarginsAdvanced" : false, "horizontalMargin" : 0,
    "intAspectMode" : 0, "intDisplayMode" : 0, "intViewingMode" : 0, "verticalMargin" : 0 },
  "time" : { "cachedLatitude" : 0, "cachedLongitude" : 0, "cachedNightShiftSunrise" : 0, "cachedNightShiftSunset" : 0,
    "darkModeNightOverride" : false, "intSolarSliceMode" : 4, "intSunWindowPlacement" : 0, "intTimeMode" : 0,
    "latitude" : "", "longitude" : "", "manualSunrise" : "09:00", "manualSunset" : "19:00", "sunEventWindow" : 10800 },
  "updatesPrefs" : { "checkForUpdates" : false, "intSparkleUpdateMode" : 0 },
  "videos" : { "allowPerVideoVibrance" : false, "allowSkips" : true, "durationCache" : { "'"$VIDEO_ID"'" : 27.333333333333332 },
    "favorites" : [ ], "globalVibrance" : 0, "hidden" : [ ], "intFadeMode" : 0, "intNewShouldPlay" : 7,
    "intOnBatteryMode" : 0, "intRefreshPeriodicity" : 0, "intVideoFormat" : 5, "lastVideoCheck" : "2026-10-15",
    "newShouldPlayString" : [ ], "playbackSpeed" : { }, "rotationOverride" : { }, "saverAdvanceAtLaunch" : false,
    "sourcesEnabled" : { "Live Feeds" : false, "My Videos" : true, "macOS" : false, "tvOS 13" : false, "tvOS 26" : false },
    "timeOfDayOverride" : { }, "vibrance" : { }, "videoFormatOverride" : { } }
}'
  put $k "$SHARED/overlay-config.json" '{
  "alwaysShowVersion" : false, "dockOffsetEnabled" : false, "hideOverlaysDuringLogin" : false, "perScreen" : false,
  "rotationMode" : "never", "screenLayouts" : { }, "separateDesktopConfig" : false,
  "sharedLayout" : { "marginBottom" : 50, "marginLeft" : 50, "marginRight" : 50, "marginTop" : 50,
    "shadowColorHex" : "#000000", "shadowOffsetX" : 0, "shadowOffsetY" : 2, "shadowOpacity" : 0.6, "shadowRadius" : 3,
    "stacks" : { }, "textColorHex" : "#FFFFFF" },
  "showVersionAtStartup" : false, "version" : 1
}'
  put $k "$SHARED/Sources/My Videos/manifest.json" '{"name":"My Videos","description":"Videos from \/Users\/Shared\/Aerial\/My Videos\/","cacheable":false,"local":true,"more":"","scenes":["Nature"],"license":"","manifestUrl":"\/Users\/Shared\/Aerial\/My Videos"}'
  put $k "$SHARED/Sources/My Videos/entries.json" '{"version":1,"initialAssetCount":1,"assets":[{"url-1080-HDR":"","pointsOfInterest":{},"url-1080-H264":"","url":"","accessibilityLabel":"My Videos","url-4K-SDR":"\/Users\/Shared\/Aerial\/My Videos\/'"$VIDEO_NAME"'","url-4K-SDR-240FPS":"","id":"'"$VIDEO_ID"'","url-4K-HDR":"","title":"'"$VIDEO_NAME"'","url-4K-SDR-120FPS":"","type":"nature","url-1080-SDR":"","scene":"city","timeOfDay":"day"}]}'
  entry='{ "duration" : 27.333333333333332, "secondaryName" : "'"$VIDEO_NAME"'", "videoId" : "'"$VIDEO_ID"'", "videoName" : "My Videos" }'
  put $k "$SHARED/Playlists/_index.json" '{ "playlists" : [ { "entryCount" : 1, "id" : "'"$PLAYLIST_ID"'", "name" : "TLA Screensaver", "order" : 0 } ], "version" : 1 }'
  put $k "$SHARED/Playlists/$PLAYLIST_ID.json" '{ "createdAt" : 813801600, "cycleMode" : 0, "entries" : [ '"$entry"' ], "id" : "'"$PLAYLIST_ID"'", "name" : "TLA Screensaver" }'
  # The screensaver plays the shared playlist ("userPlaylist:<id>" = that playlist).
  put $k "$SHARED/playlists.json" '{ "screenPlaylists" : { }, "sharedPlaylist" : { "currentIndex" : 0, "cycleMode" : 0,
  "entries" : [ '"$entry"' ], "filterMode" : -1, "filterStrings" : [ "userPlaylist:'"$PLAYLIST_ID"'" ],
  "generatedAt" : 813801600, "playbackTimestamp" : 0 }, "version" : 1 }'
  if (( new )); then
    print -r -- "Set up by TLA BootPaper $(/usr/bin/awk -F'"' '/^WV_RELEASE=/ { print $2; exit }' "$WV_DIR/common.zsh") on $(/bin/date '+%Y-%m-%d')" > "$SHARED/.tla-bootpaper"
    log "Set up Aerial to play the TLA video."
  fi
fi

# Everyone on this Mac uses the same Aerial folder, and the screensaver (running as whoever is logged in) writes
# its progress there: where TLA BootPaper set it up, the folders and settings are open to all (except My Videos,
# above). guard.zsh keeps them that way (aerial_permissions).
if [[ -f "$SHARED/.tla-bootpaper" ]]; then
  /usr/bin/find "$SHARED" -path "$SHARED/My Videos" -prune -o -type d ! -perm -0777 -exec /bin/chmod a+rwx {} + 2>/dev/null
  /usr/bin/find "$SHARED" -path "$SHARED/My Videos" -prune -o -type f ! -perm -0666 -exec /bin/chmod a+rw {} + 2>/dev/null
  /bin/chmod 1777 "$SHARED" 2>/dev/null
fi

status ready
exit 0
