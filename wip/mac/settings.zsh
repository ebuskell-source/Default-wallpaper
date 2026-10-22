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
#   --care-fix <action>     start a fix: cleanup | audio | videos (prints the time asked, then bytes freed for cleanup)
#   --care-result <action> <time asked>   the answer, once there is one
#   --unbox                 "Prepare for initial unboxing" (prints the time asked)
#   --restart               restart the Mac (after TLA Care asked them)
#   --open <wifi|touchid|storage>   that page of System Settings (5.2.5: or connect: Company Portal)
#   --care | --tour         open TLA Care, or the Welcome to TLA tour
# 5.1: --state tour also says whether this Mac has Touch ID (and whether they've set it up), whether they're a teacher
# (the "Teacher vs. Student" profile) and whether they've changed their password; --open password.
# If that window can't open, the simpler swiftDialog window below is used instead.

source "/Library/Application Support/ca.schoolathome.welcomevideo/common.zsh" 2>/dev/null || exit 0

case "$1" in
  --state)
    wv_load_settings; wv_cache_mode
    print -r -- "release	$WV_RELEASE"
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
    for f in lightdark screensaver calls care tour greeting-switch greeting-styles; do wv_released $f && print -r -- "feature	$f	1" || print -r -- "feature	$f	0"; done
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
      else after="${WV_BACKGROUND_NAMES[${WV_BACKGROUNDS[(Ie)$(wv_setting Background)]}]}"; fi
      print -r -- "temp	$t	${WV_BACKGROUND_NAMES[${WV_BACKGROUNDS[(Ie)$t]}]}	$(wv_get TempUntil)	$after"
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
      print -r -- "bg	$id	${WV_BACKGROUND_NAMES[$i]}	$v	$thumb	$f	$r	$b	${WV_CHANNEL_ONLY[$id]}"
    done
    print -r -- "bg	surprise	Surprise me	1	$WV_DIR/Backgrounds/thumbs/surprise.jpg	0	1"
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
      audio|videos) wv_care_request "$2" || exit 1 ;;
      *) exit 1 ;;
    esac
    exit 0 ;;
  --care-result) wv_care_result "$2" "$3"; exit $? ;;
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
    esac
    exit 0 ;;
  --care) result="$(/usr/bin/osascript -l JavaScript "$WV_DIR/care-app.js" "${0:A}" window 2>&1)"
          [[ "$result" == ok* ]] || wv_log "TLA Care window: ${result:-no result}"; exit 0 ;;
  --tour) result="$(/usr/bin/osascript -l JavaScript "$WV_DIR/tour-app.js" "${0:A}" app 2>&1)"
          [[ "$result" == ok* ]] || wv_log "Tour window: ${result:-no result}"; exit 0 ;;
  --tour-done)   # (the tour asked for their name, so the one-time question after the video isn't needed)
    wv_set StateNameAsked 1; wv_set StateTourDone "$(wv_today)"; wv_log "Welcome to TLA tour: done."; exit 0 ;;
esac

# The app window. If it can't open (it says why), the simpler window below is used instead.
# (4.3: --report opens it straight at "Report a problem")
result="$(/usr/bin/osascript -l JavaScript "$WV_DIR/settings-app.js" "${0:A}" ${(M)1:#--report} 2>&1)"
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
