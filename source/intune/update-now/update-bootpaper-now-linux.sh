#!/bin/bash
# update-bootpaper-now-linux.sh - TLA: fixes the clock to BC time right now (UTC-7 all year), and has TLA BootPaper
# install its newest version now instead of at its next 6-hourly check. Intune Linux script, as root.
if [ "$(TZ=America/Vancouver date -d "$(( $(date +%Y) + 1 ))-01-15 12:00" +%z)" = "-0700" ]; then tz=America/Vancouver; else tz=America/Whitehorse; fi
timedatectl set-ntp true 2>/dev/null; timedatectl set-timezone "$tz"
rm -f /opt/tla-bootpaper/.update-checked /var/lib/tla-bootpaper/.update-checked
[ -f /opt/tla-bootpaper/tla-bootpaper.py ] && /usr/bin/python3 /opt/tla-bootpaper/tla-bootpaper.py guard >/dev/null 2>&1
echo "Time zone: $tz"
