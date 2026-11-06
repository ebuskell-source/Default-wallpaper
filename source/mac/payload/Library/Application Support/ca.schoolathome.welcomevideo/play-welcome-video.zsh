#!/bin/zsh
# play-welcome-video.zsh - runs at every login (started by login-watch.zsh as soon as someone logs in, or by
# the LaunchAgent ca.schoolathome.welcomevideo as a backup). It:
#   1. puts the person's chosen desktop background back if the desktop isn't showing it,
#   2. plays the welcome video, following their choices in the TLA BootPaper app and the
#      organization defaults in org-defaults.zsh,
#   3. shows the release log once after each update.
# After that, guard.zsh (a system service, every 20 seconds) keeps the desktop picture to the presets.
# 5.0: the first login after "Prepare for initial unboxing" plays TLA Classic (whatever the settings) and then the
# Welcome to TLA tour; the TLA screensaver is set while the video plays; and a TLA Care reminder can show a few
# minutes after login (at most once a day).
# 5.7.0: after the video, a reminder to sign in again 7 and 3 days before their sign-in runs out (or, while they're
# not signed in, at most once a week).
# Installed by the TLA BootPaper package (Intune); see common.zsh for how settings combine.

source "${0:A:h}/common.zsh" 2>/dev/null || exit 0

# Skip Setup Assistant and system accounts
case "$(/usr/bin/id -un)" in
  _mbsetupuser|root|"") exit 0 ;;
esac

# Once per login: the background service (login-watch.zsh, "daemon") usually gets here first, as soon as
# someone logs in; the login item ("agent") is the backup. Whichever comes second stops here.
session="$(/usr/bin/pgrep -x -u "$UID" loginwindow | /usr/bin/head -1)"
/bin/mkdir "/tmp/tla-bootpaper-$UID-${session:-0}" 2>/dev/null || exit 0

wv_load_settings
wv_cache_mode   # (5.0: light or dark, asked once)

# Unboxing (5.0): prepared, started up since, and this person hasn't had it yet.
unbox_at="$(wv_unbox_pending)"

# 1. Desktop background, in the background while the video plays: once the desktop has loaded, put the
#    person's preset back if it isn't showing (only the presets; anything else goes back to theirs).
#    5.0: then the TLA screensaver (setting it restarts macOS's wallpaper service, which is best done while the
#    video covers the screen).
(
  for i in {1..60}; do
    /usr/bin/pgrep -x -u "$UID" Dock >/dev/null && break
    sleep 1
  done
  if wv_background_locked; then
    wv_log "Login: a configuration profile locks the desktop picture, so TLA BootPaper can't change it."
  elif wv_background_needed; then
    wv_apply_background
  fi
  if wv_released screensaver; then
    wv_set StateScreensaverAt "$(/bin/date +%s)"
    wv_set StateScreensaverStatus "$(wv_update_screensaver)"
    wv_background_needed && wv_apply_background   # (in case the restart showed an older picture)
  fi
) &

# 2. Welcome video, straight away (it covers the screen while the desktop loads behind it)
build="$(/usr/bin/sw_vers -buildVersion)"
last_build="$(wv_get StateLastSeenBuild)"

play=1
[[ "$(wv_setting Enabled)" == 0 ]] && play=0
case "$(wv_setting PlayWhen)" in
  OncePerDay)  [[ "$(wv_get StateLastPlayedDay)" == "$(/bin/date '+%Y-%m-%d')" ]] && play=0 ;;
  AfterUpdate) [[ -z "$last_build" || "$last_build" == "$build" ]] && play=0 ;;
  FirstTime)   [[ "$(wv_get StateLastPlayedVideo)" == "$(wv_video_key)" ]] && play=0 ;;
esac
if [[ -n "$unbox_at" ]]; then
  # (TLA Classic, with sound unless it's quiet hours, and it can't be skipped: the "force" video with tla)
  wv_log "Unboxing: TLA Classic, then the Welcome to TLA tour."
  wv_set StateUnboxShown "$unbox_at"; wv_set StateSeenRelease "$(wv_shown_release)"
  wv_play_video unbox tla
elif (( play )); then
  wv_play_video
fi
wv_set StateLastSeenBuild "$build"     # every login, so "after an update" can tell when it changes
wait

if [[ -n "$unbox_at" ]]; then
  # The Welcome to TLA tour (5.0).
  /usr/bin/osascript -l JavaScript "$WV_DIR/tour-app.js" "$WV_DIR/settings.zsh" unbox >/dev/null 2>&1
elif wv_corporate && wv_signed_out && wv_online; then
  # 6.4.5: on TLA's Macs, the tour again at every login until they've signed in (it asks them to, first).
  wv_log "Login: not signed in on TLA's Mac, so the Welcome to TLA tour."
  /usr/bin/osascript -l JavaScript "$WV_DIR/tour-app.js" "$WV_DIR/settings.zsh" app >/dev/null 2>&1
else
  # Once (4.0), after the video: what name should it greet them by?
  (( play )) && wv_users_can_change && ! wv_signed_out && [[ -z "$(wv_get StateNameAsked)" ]] && wv_ask_name

  # 3. Release log, once after each update
  [[ "$(wv_get StateSeenRelease)" != "$(wv_shown_release)" ]] && wv_show_whats_new   # (4.3: their channel's release)

  # 5.7.0: signing in (again)
  if [[ "${WV_SIGNIN%%	*}" != off ]]; then
    r="$(/usr/bin/osascript -l JavaScript "$WV_DIR/signin.js" remind 2>/dev/null)"
    [[ "$r" == *$'\t'* ]] && wv_signin_reminder "${r%%	*}" "${r#*	}"
  fi
fi

# A TLA Care reminder (5.0), once things have settled after login.
if wv_released care && [[ "$(wv_setting CareReminders)" != 0 ]]; then
  sleep 180
  nudge="$(wv_care_nudge)"
  [[ -n "$nudge" ]] && /usr/bin/osascript -l JavaScript "$WV_DIR/care-app.js" "$WV_DIR/settings.zsh" nudge "$nudge" >/dev/null 2>&1
fi

exit 0
