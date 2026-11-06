#!/bin/zsh
# login-watch.zsh - runs as root all the time (LaunchDaemon ca.schoolathome.welcomevideo.login), so the intro
# video starts the moment someone logs in, before the desktop appears. A login item (the LaunchAgent) only
# starts once the login is well under way, which left the desktop showing for several seconds.
# It watches who owns the screen (no programs started while idle) and, when someone logs in, runs the
# login script (play-welcome-video.zsh) as that person, in their session. The LaunchAgent still runs too,
# as a backup; the login script makes sure only one of them plays the video.

WV_DIR="/Library/Application Support/ca.schoolathome.welcomevideo"
zmodload zsh/stat zsh/zselect 2>/dev/null || exit 1

# Whoever is logged in when this starts (an update installing mid-session) doesn't get a video now.
typeset -A st=()
zstat -H st /dev/console 2>/dev/null
last="${st[uid]:-0}"
while true; do
  typeset -A st=()
  zstat -H st /dev/console 2>/dev/null
  uid="${st[uid]:-0}"
  if [[ "$uid" != 0 && "$uid" != "$last" ]]; then
    last="$uid"
    user="$(/usr/bin/id -un "$uid" 2>/dev/null)"
    case "$user" in
      root|loginwindow|_mbsetupuser|"") ;;
      *)
        (
          # Wait (up to 10 seconds) until their login session can show windows, then go.
          for i in {1..100}; do
            /bin/launchctl print "gui/$uid" >/dev/null 2>&1 && break
            zselect -t 10
          done
          /bin/launchctl asuser "$uid" /usr/bin/sudo -H -u "$user" /bin/zsh "$WV_DIR/play-welcome-video.zsh" daemon \
            >/dev/null 2>&1
        ) &!
        ;;
    esac
  elif [[ "$uid" == 0 ]]; then
    last=0                       # back at the login window
  fi
  zselect -t 20                  # check 5 times a second
done
