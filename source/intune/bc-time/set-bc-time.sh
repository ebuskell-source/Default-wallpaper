#!/bin/zsh
# set-bc-time.sh - TLA: British Columbia time, year-round UTC-7 (BC stopped changing clocks on March 8, 2026).
# Intune: Devices > macOS > Shell scripts > Add. Run script as signed-in user: No. Script frequency: Every 1 day.
# Max number of times to retry if script fails: 3.
# Uses America/Vancouver once this Mac's macOS knows BC's new rule; until then America/Whitehorse (Yukon: also UTC-7
# year-round, same clock). Running daily, a Mac moves to America/Vancouver by itself after its macOS update.
# (BC stays on UTC-7 all year now, so on a date in January Vancouver must also be -0700.)
if [[ "$(TZ=America/Vancouver /bin/date -j -f %Y-%m-%d "$(( $(/bin/date +%Y) + 1 ))-01-15" +%z)" == -0700 ]]; then
  zone=America/Vancouver
else
  zone=America/Whitehorse
fi
# Turn off "Set time zone automatically using your current location", so location can't move it back.
/usr/bin/defaults write /Library/Preferences/com.apple.timezone.auto Active -bool false
[[ "$(/usr/sbin/systemsetup -gettimezone 2>/dev/null)" == *" $zone" ]] || /usr/sbin/systemsetup -settimezone "$zone" >/dev/null
echo "Time zone: $zone ($(/bin/date '+%H:%M %z'))"
