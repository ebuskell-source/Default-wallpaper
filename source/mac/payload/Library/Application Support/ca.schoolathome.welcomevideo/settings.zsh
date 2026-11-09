#!/bin/zsh
# settings.zsh - the TLA BootPaper app (/Applications/TLA BootPaper.app runs this; called "Welcome Video" before 3.1).
# Each person chooses whether, when and which welcome video plays for them, and which of the preset
# backgrounds they get (macOS shows it on the lock screen too).
# The window is settings-app.js (the same layout as the Windows app: picture tiles for the backgrounds,
# changes save straight away). It asks this script for what to show and to make changes:
#   --state                 what to show (tab-separated lines)
#   --save <setting> <value>  (a background is saved at once; --apply then puts it in place, in the background)
#   --apply                 put the chosen background in place (the newest pick wins)
#   --seasonal              back to the seasonal theme
#   --pick <id> <Tomorrow|Week>  use a background just for today, or for a week (4.2)
#   --untemp                go back now from a background picked for a while (4.2)
#   --reset                 back to the organization's settings
#   --play [<id> [mute]]    play the intro video now (4.2: a given one, or without sound)
#   --whatsnew              the release log (markdown)
#   --details               this Mac's details for "Report a problem" (4.3; "Label: value" lines)
#   --report                open the app straight at "Report a problem" (4.3)
# 5.0:
#   --screensaver           make the TLA screensaver theirs now (or put theirs back, if they turned it off)
#   --calls add|remove|open TLA call backgrounds in Microsoft Teams, or the pictures in Finder (for Zoom and others)
#   --care-checks [quick]   TLA Care's checks (id, status, title, detail, action, action text: tab-separated lines)
#   --care-fix <action>     start a fix: cleanup | audio | videos | update (5.8.0: Check for updates) (prints the time
#                           asked, then bytes freed for cleanup)
#   --care-result <action> <time asked>   the answer, once there is one
#   --unbox                 "Prepare for initial unboxing" (prints the time asked)
#   --restart               restart the Mac (after TLA Care asked them)
#   --open <wifi|touchid|storage>   that page of System Settings (5.2.5: or connect: Company Portal)
#   --care | --tour         open TLA Care, or the Welcome to TLA tour
# 5.9.0: --own-add <picture> | --own-remove <id>   their own pictures, on a Mac of their own (see common.zsh)
# 5.1: --state tour also says whether this Mac has Touch ID (and whether they've set it up), whether they're a teacher
# (the "Teacher vs. Student" profile) and whether they've changed their password; --open password.
# 5.7.0: signing in with the Hub account (see common.zsh):
#   --signin start          start signing in: tla-signin waits for the answer, the browser opens the sign-in page;
#                           prints the file the answer will be in (the app watches for it)
#   --signin finish <file>  check what came back and save it; prints signin.js's answer (ok or error, and why)
#   --signin cancel <file>  stop waiting
#   --signin out            sign out
#   --signin status         their sign-in now (state days until kind name who reason)
#   --lock-check            (6.2.5) show the lock screen if this Mac is TLA's and they need to sign in
#   --signin-now            open the app and start signing in (the reminder's Sign in button)
# Until they sign in, nothing can be changed (--save, --pick and the rest do nothing).
# If that window can't open, the simpler swiftDialog window below is used instead.

source "/Library/Application Support/ca.schoolathome.welcomevideo/common.zsh" 2>/dev/null || exit 0

# 5.7.0: nothing changes until they've signed in.
[[ "$1" == (--save|--pick|--untemp|--seasonal|--reset|--own-add|--own-remove) ]] && wv_signed_out && exit 1

case "$1" in
  --signin)    # 5.7.0
    case "$2" in
      start)
        dir="$(/usr/bin/mktemp -d /tmp/tla-signin.XXXXXXXX)" || exit 1      # (only they can read it)
        "$WV_DIR/tla-signin" "$dir/answer" "https://ebuskell-source.github.io/Default-wallpaper/TLA-BootPaper/signin/?done=1" \
          600 > "$dir/port" 2>/dev/null &!
        print -r -- $! > "$dir/pid"
        port=""
        for i in {1..60}; do port="$(/usr/bin/head -1 "$dir/port" 2>/dev/null)"; [[ "$port" == <-> ]] && break; sleep 0.05; done
        [[ "$port" == <-> ]] || { wv_log "Sign-in: couldn't start waiting for the answer."; exit 1; }
        url="$(/usr/bin/osascript -l JavaScript "$WV_DIR/signin.js" begin "$port" 2>/dev/null)"
        [[ "$url" == https://* ]] || { wv_log "Sign-in: couldn't start ($url)."; exit 1; }
        # (6.4.5: "embed": the lock screen shows the page itself; tests: no browser)
        [[ -n "$TB_SIGNIN_NO_BROWSER" || "$3" == embed ]] && print -r -- "$url" > "$dir/url" || /usr/bin/open "$url"
        wv_log "Sign-in: started."
        print -r -- "$dir/answer"; exit 0 ;;
      finish)
        [[ "$3" == /tmp/tla-signin.*/answer && -f "$3" && ! -L "$3" ]] || exit 1
        r="$(/usr/bin/osascript -l JavaScript "$WV_DIR/signin.js" finish "$3" 2>/dev/null)"
        /bin/rm -rf "${3:h}"
        f=("${(@ps:\t:)r}")
        if [[ "${f[1]}" == ok ]]; then
          wv_log "Signed in as ${f[4]} (${f[5]})."
          # (signed with a key the guard hasn't fetched yet: it fetches the keys now, within about 20 seconds)
          [[ "${f[3]}" == 1 ]] && { wv_set CareRequest signin; wv_set CareRequestAt "$(/bin/date +%s)"; }
          /bin/zsh "${0:A}" --apply >/dev/null 2>&1 &!
        else
          wv_log "Sign-in: ${f[2]:-no answer}"
        fi
        print -r -- "${r:-error	Signing in didn't finish. Try again.}"; exit 0 ;;
      cancel)
        [[ "$3" == /tmp/tla-signin.*/answer ]] || exit 1
        pid="$(/bin/cat "${3:h}/pid" 2>/dev/null)"
        [[ "$pid" == <-> ]] && /bin/kill "$pid" 2>/dev/null
        /bin/rm -rf "${3:h}"; exit 0 ;;
      out)
        /usr/bin/osascript -l JavaScript "$WV_DIR/signin.js" out >/dev/null 2>&1
        wv_log "Signed out."
        /bin/zsh "${0:A}" --apply >/dev/null 2>&1 &!
        # (6.5.5: on TLA's Macs, the lock screen straight away, not at the next minute's check)
        (( EUID )) && /bin/launchctl kickstart "gui/$EUID/ca.schoolathome.welcomevideo.lock" >/dev/null 2>&1
        exit 0 ;;
      status) WV_SIGNIN=""; wv_signin_load; print -r -- "$WV_SIGNIN"; exit 0 ;;
    esac
    exit 1 ;;
  --state)
    wv_load_settings; wv_cache_mode
    print -r -- "release	$WV_RELEASE"
    print -r -- "signin	$WV_SIGNIN"          # (5.7.0)
    # (6.2.5: signing in is required in the tour; 6.4.5: not while offline, when it couldn't be done)
    wv_corporate && [[ "${WV_SIGNIN%%	*}" == out ]] && wv_online && print "corporate	1" || print "corporate	0"
    # 4.3: release channels: theirs, each channel's release, and what they see.
    print -r -- "channel	$(wv_channel)"
    print -r -- "shown	$(wv_shown_release)"
    for i in {1..${#WV_CHANNELS}}; do print -r -- "chan	${WV_CHANNELS[$i]}	${WV_CHANNEL_NAMES[$i]}	$(wv_channel_release ${WV_CHANNELS[$i]})"; done
    wv_released report && print "report	1" || print "report	0"
    wv_users_can_change && print "locked	0" || print "locked	1"
    wv_background_locked && print "bglocked	1" || print "bglocked	0"
    print -r -- "lastplayed	$(wv_get StateLastPlayed)"
    custom=0; for k in ${WV_SETTINGS:#(PreferredName|Greeting)}; do wv_get "$k" >/dev/null && custom=1; done
    print -r -- "custom	$custom"
    # 4.0: the seasonal theme (while it's on), what's showing today, the announcement, the helpdesk email.
    # 5.0: light or dark (what the pictures show now, and the choices), the new features (whether they're out on
    # this person's release channel), the screensaver, Teams, and unboxing.
    mode="$(wv_mode)"
    print -r -- "mode	$mode"
    # (5.5.5: and the greeting's switch and styles)
    for f in lightdark screensaver calls care tour greeting-switch greeting-styles checkupdates; do wv_released $f && print -r -- "feature	$f	1" || print -r -- "feature	$f	0"; done
    wv_own_allowed && print "feature	ownpictures	1" || print "feature	ownpictures	0"   # (5.9.0: on a Mac of their own)
    for i in {1..${#WV_LIGHTDARK}}; do print -r -- "lightdark	${WV_LIGHTDARK[$i]}	${WV_LIGHTDARK_LABELS[$i]}"; done
    print -r -- "ssstatus	$(wv_get StateScreensaverStatus)	$(/bin/cat "$WV_DIR/Screensaver/status" 2>/dev/null)"
    wv_teams_installed && print "teams	1" || print "teams	0"
    print -r -- "calls	${#${(s:;:)$(wv_get StateCallBackgroundFiles)}}"
    print -r -- "unbox	$(wv_unbox_value state)"
    wv_connect_needed && print "connect	needed" || print "connect	ok"      # (5.2.5)
    if [[ "$2" == tour ]]; then   # (5.1: only the tour needs these)
      print -r -- "touchid	$(wv_touchid_state)"
      role="$(wv_role)"; print -r -- "role	$role"
      [[ "$role" == teacher ]] && print -r -- "password	$(wv_password_state)"
    fi
    season="$(wv_season)"
    if [[ -n "$season" && -f "$(wv_background_path "$season")" ]]; then
      i=$(wv_season_index "$season")
      [[ -f "$WV_DIR/Videos/$season.mp4" ]] && f=1 || f=0
      print -r -- "season	$season	${WV_SEASONAL_NAMES[$i]}	${WV_SEASON_ENDS[$i]}	$(wv_thumb_path "$season" "$mode")	$f"
    fi
    print -r -- "current	$(wv_current_background)"
    print -r -- "currentfile	$(wv_background_path "$(wv_current_background)" "$mode")"
    # 4.2: a background picked for a while (and what comes back after), the fits, how long a pick lasts.
    print -r -- "today	$(wv_today)"
    t="$(wv_temp_background)"
    if [[ -n "$t" ]]; then
      if [[ -n "$season" ]] && wv_on_default_background; then after="${WV_SEASONAL_NAMES[$(wv_season_index "$season")]}"
      elif [[ "$(wv_setting Background)" == surprise ]]; then after="Surprise me"
      elif [[ "$(wv_setting Background)" == own-* ]]; then after="your picture"
      else after="${WV_BACKGROUND_NAMES[${WV_BACKGROUNDS[(Ie)$(wv_setting Background)]}]}"; fi
      tn="${WV_BACKGROUND_NAMES[${WV_BACKGROUNDS[(Ie)$t]}]}"; [[ "$t" == own-* ]] && tn="your picture"   # (5.9.0)
      print -r -- "temp	$t	$tn	$(wv_get TempUntil)	$after"
    fi
    for i in {1..${#WV_FITS}}; do print -r -- "fit	${WV_FITS[$i]}	${WV_FIT_LABELS[$i]}"; done
    for i in {1..${#WV_PICKFOR}}; do print -r -- "pickfor	${WV_PICKFOR[$i]}	${WV_PICKFOR_LABELS[$i]}"; done
    print -r -- "matchvideo	$(wv_match_video_id)"
    wv_on_default_background && print "ondefault	1" || print "ondefault	0"
    print -r -- "announcement	$(wv_announcement)"
    print -r -- "helpdesk	$(wv_helpdesk_link)"
    for i in {1..${#WV_QUIET}}; do print -r -- "quiet	${WV_QUIET[$i]}	${WV_QUIET_LABELS[$i]}"; done
    [[ -f "$(wv_video_file)" ]] && print "hasvideo	1" || print "hasvideo	0"
    for k in $WV_SETTINGS; do print -r -- "setting	$k	$(wv_setting $k)"; done
    for k in Video Background; do print -r -- "org	$k	$(wv_org $k)"; done
    for i in {1..${#WV_PLAYWHEN}}; do print -r -- "when	${WV_PLAYWHEN[$i]}	${WV_PLAYWHEN_LABELS[$i]}"; done
    # (4.3: the last field says whether it's out on their release channel)
    for i in {1..${#WV_VIDEOS}}; do   # (5.1: the last field says whether it has a video for each look)
      wv_released "${WV_VIDEOS[$i]}" && r=1 || r=0; wv_both_videos "${WV_VIDEOS[$i]}" && b=1 || b=0
      print -r -- "video	${WV_VIDEOS[$i]}	${WV_VIDEO_NAMES[$i]}	$r	$b"
    done
    for i in {1..${#WV_BACKGROUNDS}}; do
      id="${WV_BACKGROUNDS[$i]}"; thumb="$(wv_thumb_path "$id" "$mode")"   # (5.0: in their mode)
      wv_has_video "$id" && v=1 || v=0
      [[ -f "$WV_DIR/Videos/$id.mp4" ]] && f=1 || f=0      # (4.2: its video is here, for the play button)
      wv_released "$id" && r=1 || r=0
      wv_both_videos "$id" && b=1 || b=0                   # (5.1: a second intro video for the other look; 5.4: once it's out)
      grp="${WV_CATEGORY_OF[$id]}"   # (5.9.0: animals; 6.0.5: each one's themed section)
      print -r -- "bg	$id	${WV_BACKGROUND_NAMES[$i]}	$v	$thumb	$f	$r	$b	${WV_CHANNEL_ONLY[$id]}	$grp	${WV_CAPTIONS[$id]}"   # (6.1.0: its caption)
    done
    print -r -- "bg	surprise	Surprise me	1	$WV_DIR/Backgrounds/thumbs/surprise.jpg	0	1	0		${WV_CATEGORY_OF[surprise]}	${WV_CAPTIONS[surprise]}"
    for i in {1..${#WV_CATEGORIES}}; do print -r -- "cat	${WV_CATEGORIES[$i]}	${WV_CATEGORY_NAMES[$i]}"; done   # (6.0.5)
    # 5.9.0: their own pictures (on a Mac of their own)
    if wv_own_allowed; then for id in ${(f)"$(wv_own_pictures)"}; do print -r -- "bg	$id	Your picture	0	$WV_OWN_DIR/$id.jpg	0	1	0		own"; done; fi
    exit 0 ;;
  --save)
    wv_users_can_change || exit 1
    [[ " $WV_SETTINGS " == *" $2 "* ]] && wv_valid "$2" "$3" || exit 1
    if [[ "$2" == Background ]]; then
      wv_background_locked && exit 1
      wv_save Background "$3"
      wv_unset TempBackground; wv_unset TempUntil      # (4.2: a pick for good ends one for a while)
      # 4.0.5: saved straight away; the desktop changes in the background (newest pick wins).
      /bin/zsh "${0:A}" --apply >/dev/null 2>&1 &!
    elif [[ "$2" == Channel ]]; then    # (4.3: what's showing may change with it)
      wv_save Channel "$3"
      /bin/zsh "${0:A}" --apply >/dev/null 2>&1 &!
    elif [[ "$2" == (WallpaperFit|LockBackground|LightDark) ]]; then    # (4.2; 5.0: light or dark)
      wv_background_locked && [[ "$2" == (WallpaperFit|LightDark) ]] && exit 1
      wv_save "$2" "$3"
      /bin/zsh "${0:A}" --apply >/dev/null 2>&1 &!
    elif [[ "$2" == Screensaver ]]; then   # (5.0: kept even when it's the default: "they turned it on themselves")
      wv_set Screensaver "$3"
      wv_set StateScreensaverStatus working
      /bin/zsh "${0:A}" --screensaver >/dev/null 2>&1 &!
    else
      wv_save "$2" "$3"
    fi
    exit 0 ;;
  --pick)       # 4.2: a background just for today, or for a week; then what was there before comes back
    wv_users_can_change || exit 1
    wv_background_locked && exit 1
    wv_valid TempBackground "$2" || exit 1
    case "$3" in
      Tomorrow) until="$(wv_today)" ;;
      Week)     until="$(/bin/date -j -v+6d -f '%Y-%m-%d' "$(wv_today)" '+%Y-%m-%d' 2>/dev/null)" ;;
      *)        exit 1 ;;
    esac
    wv_valid TempUntil "$until" || exit 1
    wv_set TempBackground "$2"; wv_set TempUntil "$until"
    /bin/zsh "${0:A}" --apply >/dev/null 2>&1 &!
    exit 0 ;;
  --untemp)     # 4.2: "Go back now"
    wv_users_can_change || exit 1
    wv_unset TempBackground; wv_unset TempUntil
    /bin/zsh "${0:A}" --apply >/dev/null 2>&1 &!
    exit 0 ;;
  --seasonal)   # back to the seasonal theme: forget the background they picked
    wv_users_can_change || exit 1
    wv_background_locked && exit 1
    wv_unset Background; wv_unset TempBackground; wv_unset TempUntil
    /bin/zsh "${0:A}" --apply >/dev/null 2>&1 &!
    exit 0 ;;
  --apply)      # put the background they've chosen in place (see wv_apply_latest)
    wv_cache_mode; wv_apply_latest
    exit 0 ;;
  --reset)      # their name for the greeting stays (5.5.5: and whether the greeting is on)
    wv_users_can_change || exit 1
    ss="$(wv_get Screensaver)"
    for k in ${WV_SETTINGS:#(PreferredName|Greeting)}; do wv_unset "$k"; done
    /bin/zsh "${0:A}" --apply >/dev/null 2>&1 &!
    [[ "$ss" == 0 ]] && /bin/zsh "${0:A}" --screensaver >/dev/null 2>&1 &!   # (5.0: back on, the default)
    exit 0 ;;
  --play)     wv_play_video force "$2" "$3"; exit 0 ;;
  --whatsnew) wv_release_markdown; exit 0 ;;
  --details)  wv_device_details; exit 0 ;;
  # ---- 5.0 ----
  --screensaver)
    r="$(wv_update_screensaver force)"; wv_set StateScreensaverStatus "$r"; wv_set StateScreensaverAt "$(/bin/date +%s)"
    print -r -- "$r"; exit 0 ;;
  --calls)
    case "$2" in
      add|remove) wv_call_backgrounds "$2" ;;
      open)       /usr/bin/open "$WV_DIR/Calls" ;;
    esac
    exit 0 ;;
  --care-checks) wv_care_checks "$2"; exit 0 ;;
  --care-fix)
    case "$2" in
      cleanup) freed="$(wv_clear_my_caches)"; at="$(wv_care_request cleanup)" || exit 1; print -r -- "$at	$freed" ;;
      audio|videos|update) wv_care_request "$2" || exit 1 ;;   # (5.8.0: update)
      opencore-sequoia|opencore-tahoe) wv_care_request "$2" || exit 1 ;;   # (7.0)
      *) exit 1 ;;
    esac
    exit 0 ;;
  --care-result) wv_care_result "$2" "$3"; exit $? ;;
  --opencore)   # 7.0: what TLA Care shows before someone picks a newer macOS (opencore.zsh)
    source "$WV_DIR/opencore.zsh"
    print -r -- "model	$(oc_model)	$(oc_model_name)"
    print -r -- "offer	$(oc_offer)"
    for v in sequoia tahoe; do
      print -r -- "version	$v	${OC_NAME[$v]}	${OC_VERSION[$v]}	${OC_FREE_GB[$v]}"
      oc_issues $v | while IFS= read -r l; do print -r -- "issue	$v	$l"; done
    done
    print -r -- "state	$(oc_get phase)	$(oc_get target)	$(oc_get note)"
    exit 0 ;;
  --own-add)      # 5.9.0: a picture of their own (on a Mac of their own); prints its id ("full" at the most there can be, "small")
    wv_own_allowed || exit 1
    wv_own_add "$2"; exit $? ;;
  --own-remove)   # 5.9.0: remove one (back to the organization's background if it was in use)
    wv_own_remove "$2" || exit 1
    /bin/zsh "${0:A}" --apply >/dev/null 2>&1 &!
    exit 0 ;;
  --care-nudged)   # (the reminder showed: not the same one tomorrow unless it's worse)
    wv_set StateCareNudgeDay "$(wv_today)"; wv_set StateCareNudgeFor "$2"; exit 0 ;;
  --unbox)
    [[ "$(wv_unbox_value state)" == ready ]] || { print "already"; exit 1; }
    wv_care_request unbox; exit $? ;;
  --restart)
    /usr/bin/osascript -e 'tell application "loginwindow" to «event aevtrest»' >/dev/null 2>&1; exit $? ;;
  --open)
    case "$2" in
      wifi)    /usr/bin/open "x-apple.systempreferences:com.apple.wifi-settings-extension" ;;
      touchid|password) /usr/bin/open "x-apple.systempreferences:com.apple.Touch-ID-Settings.extension" ;;
      connect) wv_open_connect ;;   # (5.2.5: Company Portal, or its download)   # (Touch ID & Password, or Login Password: where Change… is)
      storage) /usr/bin/open "x-apple.systempreferences:com.apple.settings.Storage" ;;
      swupdate) /usr/bin/open "x-apple.systempreferences:com.apple.Software-Update-Settings.extension" ;;   # (7.6.0)
    esac
    exit 0 ;;
  --care) # 7.0.5: in the app's own program (like the lock screen), so it opens in front when the app asks for it;
          # osascript only if that can't run it
          wv_log "TLA Care: opening."
          result="$("$WV_APP/Contents/MacOS/welcome-video" --jxa "$WV_DIR/care-app.js" "${0:A}" window 2>&1)" ||
            result="$(/usr/bin/osascript -l JavaScript "$WV_DIR/care-app.js" "${0:A}" window 2>&1)"
          [[ -z "$result" || "$result" == ok* ]] || wv_log "TLA Care window: $result"; exit 0 ;;
  --tour) result="$(/usr/bin/osascript -l JavaScript "$WV_DIR/tour-app.js" "${0:A}" app 2>&1)"
          [[ "$result" == ok* ]] || wv_log "Tour window: ${result:-no result}"; exit 0 ;;
  --lock-check)   # 6.2.5: the LaunchAgent ca.schoolathome.welcomevideo.lock, every minute: the lock screen, if it's needed
    # (6.4.5: at login, it waits for the intro video and then the tour, rather than checking again a minute later)
    for pass in 1 2; do
      for i in {1..120}; do /usr/bin/pgrep -qu "$EUID" -f 'tla-player' || break; sleep 1; done
      (( pass == 1 )) && sleep 4   # (between the video and the tour)
    done
    wv_lock_needed || exit 0
    /usr/bin/pgrep -qu "$EUID" -f 'lock-app\.js' && exit 0
    "$WV_APP/Contents/MacOS/welcome-video" --jxa "$WV_DIR/lock-app.js" "${0:A}" >/dev/null 2>&1
    exit 0 ;;
  --tour-done)   # (the tour asked for their name, so the one-time question after the video isn't needed)
    wv_set StateNameAsked 1; wv_set StateTourDone "$(wv_today)"; wv_log "Welcome to TLA tour: done."; exit 0 ;;
esac

# The app window. If it can't open (it says why), the simpler window below is used instead.
# (4.3: --report opens it straight at "Report a problem")
# 5.8.0: it runs in the app's own program (launcher.c), so it's in the Dock as TLA BootPaper while it's open; if that
# can't run it, in osascript as before. (Quitting from the Dock or the menu ends it with nothing printed.)
# 6.0.5: opening the app runs the window in the app itself (launcher.c), not here. This opens the app the same way
# (one copy, so opening it again brings its window back); the report form and the sign-in reminder still get their own.
# TB_APP_FALLBACK: the app couldn't run its window (why), so osascript, then the simple window, take over here.
if [[ -z "$TB_APP_FALLBACK$TB_TEST" && -z "$1" ]] && /usr/bin/open -a "$WV_APP" 2>/dev/null; then exit 0; fi
if [[ -n "$TB_APP_FALLBACK" ]]; then
  wv_log "App window: $TB_APP_FALLBACK; using osascript."; rc=3
else
  result="$("$WV_APP/Contents/MacOS/welcome-video" --jxa "$WV_DIR/settings-app.js" "${0:A}" ${(M)1:#--(report|signin-now)} 2>/dev/null)"
  rc=$?
fi
if (( rc != 0 )); then
  [[ $rc == 3 ]] || wv_log "App window: the app couldn't run it ($rc); using osascript."
  result="$(/usr/bin/osascript -l JavaScript "$WV_DIR/settings-app.js" "${0:A}" ${(M)1:#--(report|signin-now)} 2>&1)"
elif [[ -z "$result" ]]; then
  exit 0
fi
[[ "$result" == ok* ]] && exit 0
wv_log "App window: ${result:-no result}. Using the simple window instead."
[[ -n "$TB_TEST" ]] && { print -r -- "$result"; exit 1; }
# No window for the report form: a plain email to the helpdesk, with this Mac's details, instead.
[[ "$1" == --report ]] && { /usr/bin/open "$(wv_helpdesk_link)"; exit 0; }

if [[ ! -x "$WV_DIALOG" ]]; then
  /usr/bin/osascript -e 'display alert "TLA BootPaper isn'"'"'t ready yet" message "It is still being set up on this Mac. Try again in a few minutes."' >/dev/null 2>&1
  exit 0
fi

json_value() {   # json_value <json> <key path>
  print -r -- "$1" | /usr/bin/plutil -extract "$2" raw -o - - 2>/dev/null
}

# Open no bigger than the screen (smaller MacBooks), leaving room for the menu bar and Dock.
screen="$(/usr/bin/osascript -l JavaScript -e 'ObjC.import("AppKit"); const f = $.NSScreen.mainScreen.visibleFrame; Math.round(f.size.width) + " " + Math.round(f.size.height)' 2>/dev/null)"
screen_w="${screen%% *}"; screen_h="${screen##* }"
win_width=760; win_height=860
[[ "$screen_w" == <-> ]] && (( screen_w - 40 < win_width ))  && win_width=$(( screen_w - 40 ))
[[ "$screen_h" == <-> ]] && (( screen_h - 40 < win_height )) && win_height=$(( screen_h - 40 ))
(( win_width < 560 )) && win_width=560
(( win_height < 480 )) && win_height=480

saved=0
while true; do
  locked=0;    wv_users_can_change || locked=1
  bg_locked=0; wv_background_locked && bg_locked=1

  enabled="$(wv_setting Enabled)"; sound="$(wv_setting Sound)"; skip="$(wv_setting AllowSkip)"
  when="$(wv_setting PlayWhen)";   background="$(wv_setting Background)"
  org_background="$(wv_org Background)"

  # Labels can't contain commas: swiftDialog uses them to separate options.
  when_label="${WV_PLAYWHEN_LABELS[${WV_PLAYWHEN[(Ie)$when]}]}"
  bg_labels=(); bg_ids=()     # (4.3: only what's out on their release channel)
  for i in {1..${#WV_BACKGROUNDS}}; do
    wv_released "${WV_BACKGROUNDS[$i]}" || [[ "${WV_BACKGROUNDS[$i]}" == "$org_background" ]] || continue
    label="${WV_BACKGROUND_NAMES[$i]}"
    [[ "${WV_BACKGROUNDS[$i]}" == "$org_background" ]] && label+=" (default)"
    wv_has_video "${WV_BACKGROUNDS[$i]}" || label+=" - intro video coming soon"
    bg_labels+=("$label"); bg_ids+=("${WV_BACKGROUNDS[$i]}")
  done
  bg_labels+=("Surprise me - a different one each day"); bg_ids+=(surprise)
  bg_label="${bg_labels[${bg_ids[(Ie)$background]}]}"
  quiet="$(wv_setting QuietMode)"; quiet_label="${WV_QUIET_LABELS[${WV_QUIET[(Ie)$quiet]}]}"
  pname="$(wv_setting PreferredName)"; qstart="$(wv_setting QuietStart)"; qend="$(wv_setting QuietEnd)"

  video="$(wv_setting Video)"; org_video="$(wv_org Video)"
  video_labels=(); video_ids=()
  for i in {1..${#WV_VIDEOS}}; do
    wv_released "${WV_VIDEOS[$i]}" || [[ "${WV_VIDEOS[$i]}" == "$org_video" ]] || continue
    video_ids+=("${WV_VIDEOS[$i]}")
    label="${WV_VIDEO_NAMES[$i]}"
    if [[ "${WV_VIDEOS[$i]}" == match ]]; then   # say which video that is right now
      now_bg="$(wv_match_video_id)"
      if (( ${WV_SEASONAL[(Ie)$now_bg]} )); then label+=" (${WV_SEASONAL_NAMES[${WV_SEASONAL[(Ie)$now_bg]}]})"
      elif wv_has_video "$now_bg"; then label+=" (${WV_BACKGROUND_NAMES[${WV_BACKGROUNDS[(Ie)$now_bg]}]})"
      else label+=" (TLA Classic)"; fi
    fi
    [[ "${WV_VIDEOS[$i]}" == "$org_video" ]] && label+=" - default"
    video_labels+=("$label")
  done
  video_label="${video_labels[${video_ids[(Ie)$video]}]}"

  message="Choose how your welcome video plays and your background for the desktop and lock screen. [See all the backgrounds](file:///Library/Application%20Support/ca.schoolathome.welcomevideo/picker.jpg)"
  (( saved )) && message="**Saved.** $message"
  (( locked )) && message+=" Your organization manages these settings, so they can't be changed here."
  (( bg_locked && ! locked )) && message+=" A configuration profile on this Mac locks the desktop picture, so the background can't be changed here."
  season="$(wv_season)"
  if [[ -n "$season" ]] && wv_on_default_background; then
    i=$(wv_season_index "$season")
    message+=" It's ${WV_SEASONAL_NAMES[$i]} season: your desktop shows the ${WV_SEASONAL_NAMES[$i]} theme until ${WV_SEASON_ENDS[$i]}. Pick a background to use your own instead."
  fi
  news="$(wv_announcement)"; [[ -n "$news" ]] && message="**Announcement:** $news\n\n$message"
  message+="\n\n**Have an idea or found a problem?** Email [helpdesk@schoolathome.ca]($(wv_helpdesk_link)) to ask for a new background, report a bug, or suggest how to make TLA computers better to use."
  last="$(wv_get StateLastPlayed)"
  if [[ -n "$last" ]]; then
    message+="\n\n_Version $(wv_shown_release) ($(wv_channel_name)) · Your video last played $last._"
  else
    message+="\n\n_Version $(wv_shown_release) ($(wv_channel_name)) · The video hasn't played for you on this Mac yet._"
  fi

  off=""; (( locked )) && off=",disabled"
  args=(
    --title "TLA BootPaper" --icon "$WV_ICON" --message "$message"
    --checkboxstyle switch
    --checkbox "Play the welcome video when I log in,name=enabled${${enabled:#0}:+,checked}$off"
    --checkbox "Play with sound,name=sound${${sound:#0}:+,checked}$off"
    --checkbox "Let me close it early with the Skip button,name=allowskip${${skip:#0}:+,checked}$off"
    --selecttitle "Which video,name=video" --selectvalues "${(j:,:)video_labels}" --selectdefault "$video_label"
    --selecttitle "When to play it,radio,name=playwhen" --selectvalues "${(j:,:)WV_PLAYWHEN_LABELS}" --selectdefault "$when_label"
    --selecttitle "Background (desktop and lock screen),name=background" --selectvalues "${(j:,:)bg_labels}" --selectdefault "$bg_label"
    --selecttitle "Quiet hours (no sound in class),name=quiet" --selectvalues "${(j:,:)WV_QUIET_LABELS}" --selectdefault "$quiet_label"
    --textfield "Quiet from (HH:MM),name=qstart,value=$qstart,regex=^([01][0-9]|2[0-3]):(00|15|30|45)$,regexerror=Use a time like 08:30"
    --textfield "Quiet until (HH:MM),name=qend,value=$qend,regex=^([01][0-9]|2[0-3]):(00|15|30|45)$,regexerror=Use a time like 15:00"
    --textfield "Your name for the greeting,name=pname,value=$pname"
    --infobuttontext "▶ Play my video"
    --helpmessage "## What's new\n\n$(wv_release_markdown 2)\n\nThe full list shows after each update."
    --moveable --resizable --json --width "$win_width" --height "$win_height"
  )
  if (( locked )); then
    args+=(--button1text "Close")
  else
    args+=(--button1text "Save" --button2text "Close")
  fi

  output="$("$WV_DIALOG" "${args[@]}" 2>/dev/null)"
  rc=$?

  if (( rc == 3 )); then            # "Play my video": straight away (always closable, not counted), then back here
    wv_play_video force
    continue
  fi
  (( rc == 0 && ! locked )) || break  # Cancel, Close or window closed

  # Save only what's allowed; choices that match the organization default follow it from now on.
  for key setting in enabled Enabled sound Sound allowskip AllowSkip; do
    value="$(json_value "$output" "$key")"
    [[ "$value" == true ]] && wv_save "$setting" 1
    [[ "$value" == false ]] && wv_save "$setting" 0
  done
  index="$(json_value "$output" playwhen.selectedIndex)"
  [[ "$index" == <-> ]] && (( index < ${#WV_PLAYWHEN} )) && wv_save PlayWhen "${WV_PLAYWHEN[index + 1]}"
  index="$(json_value "$output" video.selectedIndex)"
  [[ "$index" == <-> ]] && (( index < ${#video_ids} )) && wv_save Video "${video_ids[index + 1]}"
  if (( ! bg_locked )); then
    index="$(json_value "$output" background.selectedIndex)"
    if [[ "$index" == <-> ]] && (( index < ${#bg_ids} )); then
      [[ "$(wv_get Background)" != "${bg_ids[index + 1]}" && "$bg_label" != "${bg_labels[index + 1]}" ]] && wv_save Background "${bg_ids[index + 1]}"
    fi
    wv_background_needed && wv_apply_background
  fi
  index="$(json_value "$output" quiet.selectedIndex)"
  [[ "$index" == <-> ]] && (( index < ${#WV_QUIET} )) && wv_save QuietMode "${WV_QUIET[index + 1]}"
  for key setting in qstart QuietStart qend QuietEnd; do
    value="$(json_value "$output" "$key")"; wv_valid "$setting" "$value" && wv_save "$setting" "$value"
  done
  value="$(wv_trim "$(json_value "$output" pname)")"
  wv_valid PreferredName "$value" && wv_save PreferredName "$value"
  saved=1       # stay open, so people can keep adjusting (Cancel or the close button quits)
done
exit 0
