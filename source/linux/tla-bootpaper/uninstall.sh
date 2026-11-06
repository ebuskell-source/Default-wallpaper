#!/bin/bash
# uninstall.sh - removes TLA BootPaper for Linux. As root: the copy for everyone. As a person: their own copy.
# People's own backgrounds stay as they are.
if [ "$(id -u)" = 0 ]; then
  systemctl disable --now tla-bootpaper-guard.timer >/dev/null 2>&1
  rm -f /etc/systemd/system/tla-bootpaper-guard.service /etc/systemd/system/tla-bootpaper-guard.timer
  systemctl daemon-reload
  rm -f /etc/xdg/autostart/tla-bootpaper.desktop /usr/share/applications/tla-bootpaper.desktop \
        /usr/share/applications/tla-bootpaper-report.desktop /usr/share/applications/tla-bootpaper-care.desktop
  rm -rf /opt/tla-bootpaper /etc/tla-bootpaper
  rm -f /etc/opt/chrome/policies/recommended/tla-bootpaper.json /etc/chromium/policies/recommended/tla-bootpaper.json \
        /etc/chromium-browser/policies/recommended/tla-bootpaper.json \
        /etc/opt/edge/policies/recommended/tla-bootpaper.json   # (5.0: the TLA new tab page)
  # The announcement on the login screen (4.0).
  if [ -f /usr/share/gdm/dconf/95-tla-announcement ]; then
    rm -f /usr/share/gdm/dconf/95-tla-announcement; /usr/share/gdm/generate-config >/dev/null 2>&1
  fi
  if [ -f /etc/dconf/db/gdm.d/95-tla-announcement ]; then
    rm -f /etc/dconf/db/gdm.d/95-tla-announcement; dconf update >/dev/null 2>&1
  fi
else
  CONF="${XDG_CONFIG_HOME:-$HOME/.config}"; DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
  systemctl --user disable --now tla-bootpaper-guard.timer >/dev/null 2>&1
  rm -f "$CONF/systemd/user/tla-bootpaper-guard.service" "$CONF/systemd/user/tla-bootpaper-guard.timer"
  systemctl --user daemon-reload >/dev/null 2>&1
  rm -f "$CONF/autostart/tla-bootpaper.desktop" "$DATA/applications/tla-bootpaper.desktop" \
        "$DATA/applications/tla-bootpaper-report.desktop" "$DATA/applications/tla-bootpaper-care.desktop"
  rm -rf "$DATA/tla-bootpaper"
fi
echo "TLA BootPaper removed."
