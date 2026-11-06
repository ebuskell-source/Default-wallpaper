#!/bin/zsh
# update-bootpaper-now-mac.sh - TLA: fixes the clock to BC time right now (UTC-7 all year), and has TLA BootPaper
# install its newest version now instead of at its next 6-hourly check. Intune shell script, as root.
next=$(( $(/bin/date +%Y) + 1 ))
if [[ "$(TZ=America/Vancouver /bin/date -j -f '%Y-%m-%d %H:%M' "$next-01-15 12:00" +%z)" == -0700 ]]; then tz=America/Vancouver; else tz=America/Whitehorse; fi
/usr/bin/defaults write /Library/Preferences/com.apple.timezone.auto Active -bool false
/usr/sbin/systemsetup -settimezone "$tz" >/dev/null 2>&1
/bin/rm -f "/Library/Application Support/ca.schoolathome.welcomevideo/.update-check"
/bin/launchctl kickstart system/ca.schoolathome.welcomevideo.update 2>/dev/null && u="update started" || u="no BootPaper update service"
echo "Time zone: $tz; $u"
