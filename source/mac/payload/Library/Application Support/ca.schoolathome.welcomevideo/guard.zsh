#!/bin/zsh
# guard.zsh - runs as root every 20 seconds (LaunchDaemon ca.schoolathome.welcomevideo.guard).
# If the person logged in at the screen has a desktop picture other than their TLA BootPaper preset
# (for example one picked in System Settings), it puts the preset back. macOS shows the desktop picture
# on the lock screen too, so this keeps both to the presets.
# It also installs swiftDialog and downloads the intro videos if the package couldn't. It runs as a system service so people without admin rights can't quit or unload it. The picture itself
# is set in the person's own session (launchctl asuser), exactly like the TLA BootPaper app does.
# 5.0: the light or dark picture as macOS switches (within 20 seconds); the TLA screensaver (setting up Aerial,
# then each person's screensaver every 15 minutes until it's set); TLA Care's fixes that need root (one word from a
# fixed list, asked for by the person in TLA Care); and "Prepare for initial unboxing".

WV_DIR="/Library/Application Support/ca.schoolathome.welcomevideo"
LOG_FILE="/Library/Logs/ca.schoolathome.welcomevideo.log"
log() { print -r -- "$(/bin/date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG_FILE"; }
# True (and touches the stamp) when the stamp is older than <minutes>, or missing.
due() {   # due <stamp file> <minutes>
  [[ ! -f "$1" || -n "$(/usr/bin/find "$1" -mmin +$2 2>/dev/null)" ]] || return 1
  /usr/bin/touch "$1"
}

# 5.9.0: how this Mac is enrolled, for "their own pictures" (common.zsh, wv_owned_by_tla): dep = set up through Apple
# School or Business Manager (TLA's), mdm = connected some other way (like Company Portal), none = not managed. Only
# root can always ask macOS, so it's noted here, once an hour.
if due "$WV_DIR/Care/.enrollment-check" 60; then
  /bin/mkdir -p "$WV_DIR/Care"
  e="$(/usr/bin/profiles status -type enrollment 2>/dev/null)"
  if [[ -n "$e" ]]; then
    if [[ "$e" == *"Enrolled via DEP: Yes"* ]]; then e=dep; elif [[ "$e" == *"MDM enrollment: Yes"* ]]; then e=mdm; else e=none; fi
    if [[ "$(/bin/cat "$WV_DIR/Care/enrollment" 2>/dev/null)" != "$e" ]]; then
      print -r -- "$e" > "$WV_DIR/Care/enrollment"; /bin/chmod 644 "$WV_DIR/Care/enrollment"
      log "Enrollment: $e."
    fi
  fi
fi

# Intro videos still missing or out of date? Download them, every 15 minutes until they're all in place.
# (5.0: sync-videos.zsh marks .videos-ok itself, and only one copy downloads at a time.)
if [[ ! -f "$WV_DIR/.videos-ok" || -n "$(/usr/bin/find "$WV_DIR/.videos-ok" -mmin +15 2>/dev/null)" ]]; then
  due "$WV_DIR/.videos-attempt" 15 && /bin/zsh "$WV_DIR/sync-videos.zsh" >/dev/null 2>&1
fi

# swiftDialog missing (the install couldn't download it)? Try again every 15 minutes.
if [[ ! -x /usr/local/bin/dialog ]]; then
  due "$WV_DIR/.dialog-attempt" 15 && /bin/zsh "$WV_DIR/install-dialog.zsh" >/dev/null 2>&1
fi

# 7.4.0: BC time, UTC-7 all year (BC stopped changing clocks on March 8, 2026): America/Vancouver once this Mac's
# macOS knows that rule, America/Whitehorse (Yukon, the same clock) until then. Automatic time zone (by location) off,
# so it can't switch back to the old Pacific rules.
if due "$WV_DIR/.tz-checked" 5; then
  next=$(( $(/bin/date +%Y) + 1 ))
  if [[ "$(TZ=America/Vancouver /bin/date -j -f '%Y-%m-%d %H:%M' "$next-01-15 12:00" +%z 2>/dev/null)" == -0700 ]]; then
    tz=America/Vancouver
  else
    tz=America/Whitehorse
  fi
  /usr/bin/defaults write /Library/Preferences/com.apple.timezone.auto Active -bool false 2>/dev/null
  cur="$(/usr/sbin/systemsetup -gettimezone 2>/dev/null | /usr/bin/awk -F': ' '{ print $2 }')"
  if [[ "$cur" != "$tz" ]]; then
    /usr/sbin/systemsetup -settimezone "$tz" >/dev/null 2>&1 && log "Time zone set to $tz (BC time, UTC-7 all year; it was ${cur:-unknown})."
  fi
fi

# 7.2.5: the clock. If it's more than 2 minutes off GitHub's server time (someone set it by hand, say), network time
# goes back on and the clock is set right, every 15 minutes until it is. (Sign-ins are checked against the right time.)
if due "$WV_DIR/.clock-checked" 15; then
  d="$(/usr/bin/curl -fsSI --max-time 10 https://raw.githubusercontent.com/ebuskell-source/Default-wallpaper/main/TLA-BootPaper/auth.json 2>/dev/null |
       /usr/bin/awk -F': ' 'tolower($1) == "date" { sub(/\r$/, "", $2); print $2; exit }')"
  net="$(/bin/date -j -u -f '%a, %d %b %Y %H:%M:%S GMT' "$d" +%s 2>/dev/null)"
  off=0; [[ "$net" == <-> ]] && off=$(( net - $(/bin/date +%s) )); (( off < 0 )) && off=$(( -off ))
  if (( off > 120 )); then
    log "The clock is $(( ($(/bin/date +%s) - net) / 60 )) minutes off; setting it from network time."
    /usr/sbin/systemsetup -setusingnetworktime on >/dev/null 2>&1
    /usr/bin/sntp -sS time.apple.com >/dev/null 2>&1 || /bin/date -u "$(/bin/date -j -u -f %s "$net" +%m%d%H%M%Y.%S)" >/dev/null 2>&1
  fi
fi

# 5.7.0: the sign-in settings (auth.json) and the keys sign-ins are checked against, every 6 hours, into SignIn/.
if [[ -f "$WV_DIR/signin.js" ]] && due "$WV_DIR/.signin-checked" 360; then
  log "Sign-in settings: $(/usr/bin/osascript -l JavaScript "$WV_DIR/signin.js" refresh 2>&1)"
fi

# The TLA screensaver (5.0): Aerial and its settings, every 15 minutes until ready (then once a day, to put back
# anything missing).
/bin/mkdir -p "$WV_DIR/Care"
ss="$(/bin/cat "$WV_DIR/Screensaver/status" 2>/dev/null)"
if [[ "$ss" == ready ]]; then
  due "$WV_DIR/.screensaver-attempt" 1440 && /bin/zsh "$WV_DIR/screensaver-setup.zsh" >/dev/null 2>&1
  # Everyone's screensaver writes its progress there: keep TLA BootPaper's Aerial folder open to all (it makes
  # files only its owner can read). Every 10 minutes.
  if [[ -f /Users/Shared/Aerial/.tla-bootpaper ]] && due "$WV_DIR/.aerial-perms" 10; then
    /usr/bin/find /Users/Shared/Aerial -path "/Users/Shared/Aerial/My Videos" -prune -o \( -type d ! -perm -0777 \) -exec /bin/chmod a+rwx {} + 2>/dev/null
    /usr/bin/find /Users/Shared/Aerial -path "/Users/Shared/Aerial/My Videos" -prune -o \( -type f ! -perm -0666 \) -exec /bin/chmod a+rw {} + 2>/dev/null
  fi
elif [[ "$ss" != needs-macos-26 ]]; then
  due "$WV_DIR/.screensaver-attempt" 15 && /bin/zsh "$WV_DIR/screensaver-setup.zsh" >/dev/null 2>&1
fi

# ---- Unboxing (5.0): from prepared to done --------------------------------------------------------------------
unbox_value() { /usr/bin/awk -F= -v k="$1" '$1 == k { print substr($0, length(k) + 2); exit }' "$WV_DIR/Care/unbox" 2>/dev/null }
unbox_write() {   # unbox_write <state> [armed_at] [armed_by]
  { print -r -- "state=$1"; [[ -n "$2" ]] && print -r -- "armed_at=$2"; [[ -n "$3" ]] && print -r -- "armed_by=$3"
    print -r -- "changed=$(/bin/date +%s)"; } > "$WV_DIR/Care/.unbox.$$" &&
    /bin/chmod 644 "$WV_DIR/Care/.unbox.$$" && /bin/mv -f "$WV_DIR/Care/.unbox.$$" "$WV_DIR/Care/unbox"
}
unbox="$(unbox_value state)"; armed_at="$(unbox_value armed_at)"
if [[ "$unbox" == armed && "$armed_at" == <-> ]]; then
  boot="$(/usr/sbin/sysctl -n kern.boottime 2>/dev/null)"; boot="${${boot#*sec = }%%,*}"
  if [[ "$boot" == <-> ]] && (( boot > armed_at )); then
    unbox_write unboxing "$armed_at" "$(unbox_value armed_by)"; unbox=unboxing
    log "First startup after preparing for unboxing: TLA Classic and the Welcome to TLA tour play at the next login."
  fi
fi

user="$(/usr/bin/stat -f %Su /dev/console 2>/dev/null)"
case "$user" in
  root|loginwindow|_mbsetupuser|"") exit 0 ;;     # nobody logged in yet, or Setup Assistant
esac
uid="$(/usr/bin/id -u "$user" 2>/dev/null)" || exit 0
[[ "$uid" == <-> ]] || exit 0

# Only once the desktop has finished loading (the login script handles the first moments).
/usr/bin/pgrep -x -u "$uid" Dock >/dev/null || exit 0

# 5.7.0: whether they've signed in (as them: signin.js checks their sign-in), at most every 2 minutes, or when their
# preferences change (they've just signed in or out). Kept here, where only root can write; passed in below.
signin=""
if [[ -f "$WV_DIR/signin.js" ]]; then
  cache="$WV_DIR/SignIn/state-$uid"
  home="$(/usr/bin/dscl . -read "/Users/$user" NFSHomeDirectory 2>/dev/null | /usr/bin/awk '{ print $2 }')"
  plist="${home:-/Users/$user}/Library/Preferences/ca.schoolathome.welcomevideo.plist"
  if [[ -f "$cache" && -z "$(/usr/bin/find "$cache" -mmin +2 2>/dev/null)" && ! "$plist" -nt "$cache" ]]; then
    signin="$(<"$cache")"
  else
    signin="$(/bin/launchctl asuser "$uid" /usr/bin/sudo -H -u "$user" /bin/zsh -c \
      'source "$1/common.zsh" 2>/dev/null && print -r -- "$WV_SIGNIN"' guard "$WV_DIR" 2>/dev/null)"
    if [[ "$signin" == (in|renew|grace|out|off)* ]]; then
      /bin/mkdir -p "$WV_DIR/SignIn" && print -r -- "$signin" > "$cache.$$" && /bin/mv -f "$cache.$$" "$cache"
    else
      signin=""
    fi
  fi
fi

# Put their preset back if needed, and find out which picture it is (4.0: the seasonal theme or today's
# "Surprise me" pick, when that applies). Also what they use, for the popularity report (below).
# 5.0: in their light or dark mode; their screensaver every 15 minutes until it's set; and their TLA Care request.
out="$(/bin/launchctl asuser "$uid" /usr/bin/sudo -H -u "$user" /bin/zsh -c \
  'WV_SIGNIN="$3"; source "$1/common.zsh" 2>/dev/null || exit 0; wv_cache_mode; wv_background_needed && wv_apply_background >/dev/null 2>&1
   bg="$(wv_current_background)"
   chosen=default; wv_on_default_background || chosen="$(wv_reported_background "$(wv_setting Background)")"
   print -r -- "pop	$(wv_reported_background "$bg")	$chosen	$(wv_setting Video)	$(wv_setting Enabled)	$(wv_setting QuietMode)	${${$(wv_greeting):+1}:-0}"
   print -r -- "channel	$(wv_channel)"
   print -r -- "five	$(wv_setting LightDark)	$(wv_get StateScreensaverStatus)"
   at="$(wv_get StateScreensaverAt)"
   if [[ "$2" == ready && ( "$at" != <-> || $(( $(/bin/date +%s) - at )) -gt 900 ) ]]; then
     wv_set StateScreensaverAt "$(/bin/date +%s)"; wv_set StateScreensaverStatus "$(wv_update_screensaver)"
   fi
   req="$(wv_get CareRequest)"; [[ -n "$req" ]] && { wv_unset CareRequest; print -r -- "care	$req	$(wv_get CareRequestAt)"; }
   print -r -- "unboxshown	$(wv_get StateUnboxShown)"
   wv_background_locked || wv_shown_path "$(wv_lock_background)"' guard "$WV_DIR" "$ss" "$signin" 2>/dev/null)"   # (4.2: the lock screen background, its own if they picked one)
lines=("${(@f)out}")
src="${lines[-1]}"
field() { local l="${${(@M)lines:#$1	*}[1]}"; print -r -- "${l#$1	}" }   # the rest of the line that starts with <name><tab>

# ---- macOS updates, TLA Care's own check (7.6.0) ------------------------------------------------------------
# softwareupdate -l asks Apple now (not macOS's last automatic check). It takes up to a minute or two, so it runs in
# the background: every 6 hours, or sooner when TLA Care asks ("osupdate"). Answer in Care/osupdate, readable by all:
# line 1 the time it finished (or "error <time>"), then one line per update: <title><tab><size in KiB>.
wv_os_check() {
  local lock="$WV_DIR/Care/.osupdate.running"
  [[ -e "$lock" && $(( $(/bin/date +%s) - $(/usr/bin/stat -f %m "$lock") )) -lt 900 ]] && return 0   # (one at a time)
  /bin/mkdir -p "$WV_DIR/Care"; : > "$lock"
  (
    local out tmp="$WV_DIR/Care/.osupdate.$$"
    if out="$(/usr/sbin/softwareupdate -l 2>&1)"; then
      { /bin/date +%s
        print -r -- "$out" | /usr/bin/sed -n 's/^[[:space:]]*Title: \(.*\), Version: .*Size: \([0-9]*\)K.*/\1	\2/p'; } > "$tmp"
    else
      print -r -- "error $(/bin/date +%s)" > "$tmp"
    fi
    /bin/chmod 644 "$tmp"; /bin/mv -f "$tmp" "$WV_DIR/Care/osupdate"; /bin/rm -f "$lock"
  ) >/dev/null 2>&1 &!
}
osdone="$(/usr/bin/head -1 "$WV_DIR/Care/osupdate" 2>/dev/null)"; osdone="${osdone#error }"
[[ "$osdone" == <-> ]] && (( $(/bin/date +%s) - osdone < 21600 )) || wv_os_check

# ---- TLA Care requests (5.0) ----------------------------------------------------------------------------------
# One word from a fixed list, asked for in the last 10 minutes; the answer goes in Care/result.
care="$(field care)"
if [[ -n "$care" ]]; then
  request="${care%%	*}"; at="${care#*	}"
  result() { print -r -- "$request|$at|$1" > "$WV_DIR/Care/.result.$$" && /bin/chmod 644 "$WV_DIR/Care/.result.$$" &&
             /bin/mv -f "$WV_DIR/Care/.result.$$" "$WV_DIR/Care/result"; }
  if [[ "$request" != (cleanup|audio|videos|unbox|signin|update|osupdate|opencore-sequoia|opencore-tahoe) || "$at" != <-> ]] || (( $(/bin/date +%s) - at > 600 )); then
    log "TLA Care: ignored a request ('$request')."
  else
    case "$request" in
      osupdate)   # (7.6.0: TLA Care was opened and the last check is over an hour old)
        wv_os_check; result "Checking now." ;;
      audio)
        /usr/bin/killall coreaudiod 2>/dev/null   # (macOS starts it again straight away)
        sleep 2
        /usr/bin/pgrep -x coreaudiod >/dev/null || /bin/launchctl kickstart -k system/com.apple.audio.coreaudiod 2>/dev/null
        log "TLA Care: restarted the sound system for $user."
        result "Done: the sound system was restarted. If there's still no sound, check the volume, then report the problem." ;;
      cleanup)
        before="$(/bin/df -k /System/Volumes/Data | /usr/bin/awk 'NR == 2 { print $4 }')"
        /usr/bin/tmutil thinlocalsnapshots / 999999999999 4 >/dev/null 2>&1      # (local Time Machine snapshots)
        /usr/bin/find /private/var/tmp /Library/Logs/DiagnosticReports -type f -mtime +7 -delete 2>/dev/null
        sleep 2
        after="$(/bin/df -k /System/Volumes/Data | /usr/bin/awk 'NR == 2 { print $4 }')"
        freed=$(( ${after:-0} - ${before:-0} ))
        log "TLA Care: cleaned up for $user ($(( freed / 1024 )) MB)."
        if (( freed >= 100 * 1024 )); then result "$(printf 'Freed %.1f GB.' $(( freed / 1048576.0 )))"
        else result "Done. There wasn't much to clear: the rest is your own files and apps. To see what's using the space, open Storage settings."; fi ;;
      signin)
        # 5.7.0: a sign-in signed with a key this Mac hasn't fetched yet: fetch the keys now (at most once a minute).
        /bin/mkdir -p "$WV_DIR/SignIn"
        if due "$WV_DIR/SignIn/.forced" 1; then
          log "Sign-in settings (asked for by $user): $(/usr/bin/osascript -l JavaScript "$WV_DIR/signin.js" refresh 2>&1)"
          /bin/rm -f "$WV_DIR/SignIn/state-$uid"
        fi
        result "Done." ;;
      update)
        # 5.8.0: "Check for updates" in the app: mac/latest.json in the organization's GitHub repository, and when it
        # has a newer version, the update service (update.zsh) starts now instead of within 6 hours, and installs it.
        # (5.9.5: on every Mac. Until then, a Mac Intune managed only said that Intune sends new versions. And when
        # there's one, Care/update says it's starting, so the app can follow the install: see update.zsh.)
        ukey() { local -a p=(${(s:.:)1} 0 0 0 0); printf '%04d%04d%04d%04d' $(( 10#${p[1]} )) $(( 10#${p[2]} )) $(( 10#${p[3]} )) $(( 10#${p[4]} )) }
        latest="$(/usr/bin/curl -fsSL --connect-timeout 10 --max-time 20 \
          "https://raw.githubusercontent.com/ebuskell-source/Default-wallpaper/main/TLA-BootPaper/mac/latest.json" 2>/dev/null |
          /usr/bin/plutil -extract version raw -o - - 2>/dev/null)"
        # (7.0: "release", where latest.json has one, is the real version: see update.zsh)
        rel="$(/usr/bin/curl -fsSL --connect-timeout 10 --max-time 20 \
          "https://raw.githubusercontent.com/ebuskell-source/Default-wallpaper/main/TLA-BootPaper/mac/latest.json" 2>/dev/null |
          /usr/bin/plutil -extract release raw -o - - 2>/dev/null)"
        [[ "$rel" =~ '^[0-9]{1,4}(\.[0-9]{1,4}){0,3}$' ]] && latest="$rel"
        installed="$(/usr/bin/awk -F'"' '/^WV_RELEASE=/ { print $2; exit }' "$WV_DIR/common.zsh" 2>/dev/null)"
        if [[ ! "$latest" =~ '^[0-9]{1,4}(\.[0-9]{1,4}){0,3}$' || -z "$installed" ]]; then
          log "Check for updates (asked for by $user): couldn't read latest.json."
          result "Couldn't reach TLA's update server. Check that this Mac is online, then try again."
        elif [[ "$(ukey "$latest")" > "$(ukey "$installed")" ]]; then
          /bin/rm -f "$WV_DIR/.update-check"
          /bin/mkdir -p "$WV_DIR/Care" && print -r -- "starting	$latest	$(/bin/date +%s)	" > "$WV_DIR/Care/.update.$$" &&
            /bin/chmod 644 "$WV_DIR/Care/.update.$$" && /bin/mv -f "$WV_DIR/Care/.update.$$" "$WV_DIR/Care/update"
          /bin/launchctl kickstart system/ca.schoolathome.welcomevideo.update 2>/dev/null   # (no -k: an install already running carries on)
          log "Check for updates (asked for by $user): $latest is out; started the update."
          result "Version $latest is out (this Mac has $installed). Installing it now: this takes a few minutes."
        else
          log "Check for updates (asked for by $user): up to date ($installed)."
          result "You're up to date: $installed is the newest version."
        fi
        ;;
      opencore-sequoia|opencore-tahoe)
        # 7.0: a newer macOS with OpenCore Legacy Patcher, which opencore.zsh carries through (its LaunchDaemon).
        source "$WV_DIR/opencore.zsh"; OC_ROOT=1; target="${request#opencore-}"
        ocp="$(oc_get phase)"
        if [[ "$ocp" == (prepare|fetch|installing) ]]; then
          result "Already upgrading to ${OC_NAME[$(oc_get target)]}."
        elif [[ "$(oc_offer)" != offer*"$target"* ]]; then
          log "OpenCore: $user asked for $target, which this Mac isn't offered."; result "${OC_NAME[$target]} isn't available for this Mac."
        else
          /bin/rm -f "$OC_STATE"
          oc_set target "$target" oclp "${OC_VERSION[$target]}" user "$user" asked "$(/bin/date +%s)"
          oc_phase prepare "Getting ready: checking the charger and free space, then downloading OpenCore Legacy Patcher."
          log "OpenCore: $user started the upgrade to ${OC_NAME[$target]} (OCLP ${OC_VERSION[$target]}) on $(oc_model)."
          /bin/launchctl kickstart system/ca.schoolathome.welcomevideo.opencore 2>/dev/null
          result "Started. TLA Care shows how it's going; the Mac restarts by itself along the way."
        fi ;;
      videos)
        # (the next run of this guard, in 20 seconds, downloads them: see the top)
        /bin/rm -f "$WV_DIR/.videos-attempt" "$WV_DIR/.videos-ok"
        result "Downloading now. Check again in a few minutes." ;;
      unbox)
        if [[ "$unbox" == ready ]]; then
          unbox_write armed "$(/bin/date +%s)" "$user"
          log "Prepared for unboxing by $user; shutting down."
          result "Shutting down."
          # Like choosing Shut Down from the Apple menu (apps close normally), then for certain after 30 seconds.
          # (launchd stops whatever this guard leaves running, so it waits here instead.)
          # 5.3: the polite request runs on its own: macOS can hold it up for minutes (asking whether it may, or
          # waiting on an app that won't quit), which looked like nothing happening.
          /bin/launchctl asuser "$uid" /usr/bin/sudo -u "$user" /usr/bin/osascript -e 'tell application "loginwindow" to «event aevtshut»' >/dev/null 2>&1 &
          sleep 30
          /sbin/shutdown -h now 'TLA BootPaper: ready for unboxing' >/dev/null 2>&1
          exit 0
        else
          result "This Mac has already been prepared for unboxing."
        fi ;;
    esac
  fi
fi

# ---- Unboxing (5.0): done once someone has had the tour ------------------------------------------------------
if [[ "$unbox" == (armed|unboxing) && "$armed_at" == <-> && "$(field unboxshown)" == "$armed_at" ]]; then
  unbox_write done "$armed_at" "$(unbox_value armed_by)"
  log "Unboxing done ($user had the Welcome to TLA tour)."
fi

# ---- By itself (5.0): the sound system, and storage that's nearly full -----------------------------------------
if ! /usr/bin/pgrep -x coreaudiod >/dev/null 2>&1 && due "$WV_DIR/Care/.audio-kick" 30; then
  /bin/launchctl kickstart system/com.apple.audio.coreaudiod 2>/dev/null && log "TLA Care: the sound system had stopped; started it."
fi
if due "$WV_DIR/Care/.storage-check" 60; then
  pct="$(/bin/df -k /System/Volumes/Data | /usr/bin/awk 'NR == 2 && $2 > 0 { print int(100 * $4 / $2) }')"
  if [[ "$pct" == <-> ]] && (( pct < 10 )) && due "$WV_DIR/Care/.storage-thin" 1440; then
    /usr/bin/tmutil thinlocalsnapshots / 999999999999 4 >/dev/null 2>&1 && log "TLA Care: storage under 10% free; thinned local snapshots."
  fi
fi

# Popularity (4.0): one small file per person (by user ID: no names), read by the Intune custom attribute
# "TLA BootPaper popularity" (popularity-attribute.zsh).
# 4.1.5: (@) keeps the matching line whole; without it, [1] took just its first letter ("p"), so the report
# showed "Showing: p" and a date where the chosen background belongs. The greeting is always 0 or 1: an empty
# field there made the following ones shift.
# 5.0: then light or dark (their setting) and the screensaver (what happened), after the release channel.
pop="$(field pop)"
channel="$(field channel)"   # (4.3: their release channel, after the date)
five="$(field five)"
if [[ -n "$pop" ]]; then
  line="$pop	$(/bin/date '+%Y-%m-%d')	${channel:-stable}${five:+	$five}"
  if [[ "$(/bin/cat "$WV_DIR/Popularity/$uid.tsv" 2>/dev/null)" != "$line" ]]; then   # (only when it changes)
    /bin/mkdir -p "$WV_DIR/Popularity"
    print -r -- "$line" > "$WV_DIR/Popularity/$uid.tsv.tmp" && /bin/mv -f "$WV_DIR/Popularity/$uid.tsv.tmp" "$WV_DIR/Popularity/$uid.tsv"
  fi
fi

# The lock screen shows its own saved copy of the desktop picture, which macOS only refreshes now and then,
# so it could show an older background than the desktop. Keep that copy in step with the person's preset.
[[ "$src" == /* && -f "$src" ]] || exit 0
guid="$(/usr/bin/dscl . -read "/Users/$user" GeneratedUID 2>/dev/null | /usr/bin/awk '{ print $2 }')"
[[ -n "$guid" ]] || exit 0
cache="/Library/Caches/Desktop Pictures/$guid"
stamp="$src $(/usr/bin/stat -f %m "$src")"
# (4.2: with the copy's own date, so a copy macOS made since is replaced too: the lock screen can have its own
# background, which macOS doesn't know about)
[[ -f "$cache/lockscreen.png" && "$(/bin/cat "$cache/.tla-bootpaper" 2>/dev/null)" == "$stamp|$(/usr/bin/stat -f %m "$cache/lockscreen.png")" ]] && exit 0
/bin/mkdir -p "$cache"
owner="$(/usr/bin/stat -f %Su "$cache" 2>/dev/null)"; [[ "$owner" == root ]] && owner="$user"
if /usr/bin/sips -s format png "$src" --out "$cache/.lockscreen.tmp.png" >/dev/null 2>&1; then
  /bin/mv -f "$cache/.lockscreen.tmp.png" "$cache/lockscreen.png"
  /usr/sbin/chown "$owner" "$cache" "$cache/lockscreen.png" 2>/dev/null
  /bin/chmod 755 "$cache"; /bin/chmod 644 "$cache/lockscreen.png"
  print -r -- "$stamp|$(/usr/bin/stat -f %m "$cache/lockscreen.png")" > "$cache/.tla-bootpaper"
  log "Lock screen picture for $user set to ${src:t}."
fi
exit 0
