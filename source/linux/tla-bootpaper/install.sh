#!/bin/bash
# install.sh - installs or updates TLA BootPaper for Linux (Ubuntu with GNOME), from the unpacked bundle. Run by
# the Intune Linux script (bootstrap.sh). Works two ways:
#   as root (Intune's "Root" context): installed for everyone, in /opt/tla-bootpaper
#   by someone without admin rights:   installed just for them, in ~/.local/share/tla-bootpaper
# Takes effect at the next login; the TLA BootPaper app is in Activities straight away.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
VERSION="$(cat "$HERE/VERSION")"

if [ "$(id -u)" = 0 ]; then
  MODE=system
  DEST=/opt/tla-bootpaper
  LOG=/var/log/tla-bootpaper.log
else
  MODE=user
  HOME="${HOME:-$(getent passwd "$(id -u)" | cut -d: -f6)}"
  DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
  CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
  DEST="$DATA/tla-bootpaper"
  mkdir -p "$CONF/tla-bootpaper"
  LOG="$CONF/tla-bootpaper/install.log"
fi
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG" 2>/dev/null; echo "$*"; }
log "---- TLA BootPaper $VERSION installing ($MODE) ----"
# (5.0: an update, not a first install, for "Prepare for initial unboxing")
WAS_INSTALLED=0; [ -f "$DEST/VERSION" ] && WAS_INSTALLED=1

# What it uses: mpv plays the intro videos (without it, GStreamer from Ubuntu's desktop does), and Python's GTK
# bindings draw the app window. Only root can add missing packages.
need=()
for p in mpv python3-gi gir1.2-gtk-3.0; do dpkg -s "$p" >/dev/null 2>&1 || need+=("$p"); done
if [ ${#need[@]} -gt 0 ]; then
  if [ "$MODE" = system ]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get install -y --no-install-recommends "${need[@]}" >/dev/null 2>&1 \
      || { apt-get update >/dev/null 2>&1; apt-get install -y --no-install-recommends "${need[@]}" >/dev/null 2>&1; } \
      || log "WARNING: couldn't install ${need[*]} (offline?); will try again next time."
  else
    log "Note: ${need[*]} not installed (needs an administrator). The intro video plays with GStreamer instead."
  fi
fi

# Files
mkdir -p "$DEST/Backgrounds/thumbs" "$DEST/Videos"
cp -f "$HERE"/tla-bootpaper.py "$HERE"/greeting.lua "$HERE"/mpv-skip.conf "$HERE"/mpv-noskip.conf "$HERE"/release-notes.md \
      "$HERE"/AppIcon.png "$DEST/"
cp -f "$HERE"/Backgrounds/*.jpg "$DEST/Backgrounds/"
cp -f "$HERE"/Backgrounds/thumbs/*.jpg "$DEST/Backgrounds/thumbs/"
chmod 755 "$DEST/tla-bootpaper.py"
# The .desktop files and the guard units point at where it's installed.
fill() { sed "s#/opt/tla-bootpaper#$DEST#g" "$1" > "$2"; chmod 644 "$2"; }

if [ "$MODE" = system ]; then
  mkdir -p /etc/tla-bootpaper
  cp -f "$HERE/org-defaults.json" /etc/tla-bootpaper/org-defaults.json
  # 5.0: TLA Care (the guard writes its answers here, for people's TLA Care window), and unboxing. A computer TLA
  # BootPaper is installed on for the first time (it's being set up) can be prepared for unboxing, when the admin
  # decides. One that already had it is in someone's hands: TLA Classic and the Welcome to TLA tour come by
  # themselves at the first login after its next startup (as if prepared now, by "update").
  mkdir -p "$DEST/Care"
  for v in /home/*/.local/share/tla-bootpaper/VERSION; do [ -f "$v" ] && WAS_INSTALLED=1; done   # (installed for one person before)
  if [ ! -f /etc/tla-bootpaper/unbox.json ]; then
    now="$(date +%s)"
    if [ "$WAS_INSTALLED" = 1 ]; then
      printf '{"state": "armed", "armed_at": %s, "armed_by": "update", "changed": %s}\n' "$now" "$now" \
        > /etc/tla-bootpaper/unbox.json
      log "Unboxing: the Welcome to TLA tour at the next startup (already in use)."
    else
      printf '{"state": "ready", "changed": %s}\n' "$now" > /etc/tla-bootpaper/unbox.json
      log "Unboxing: ready."
    fi
    chmod 644 /etc/tla-bootpaper/unbox.json
  fi
  chown -R root:root "$DEST" /etc/tla-bootpaper
  chmod -R go-w "$DEST" /etc/tla-bootpaper
  mkdir -p /etc/xdg/autostart /usr/share/applications
  fill "$HERE/tla-bootpaper-autostart.desktop" /etc/xdg/autostart/tla-bootpaper.desktop
  fill "$HERE/tla-bootpaper.desktop" /usr/share/applications/tla-bootpaper.desktop
  fill "$HERE/tla-bootpaper-report.desktop" /usr/share/applications/tla-bootpaper-report.desktop   # (4.3)
  fill "$HERE/tla-bootpaper-care.desktop" /usr/share/applications/tla-bootpaper-care.desktop       # (5.0)
  update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
  # 5.0: the TLA new tab page in Chrome, Chromium and Edge (a recommended policy: people can still pick their own).
  # (Firefox has no policy for its new tab page.)
  NEWTAB='{ "NewTabPageLocation": "https://ebuskell-source.github.io/Default-wallpaper/TLA-BootPaper/newtab/" }'
  for d in /etc/opt/chrome/policies/recommended /etc/chromium/policies/recommended /etc/chromium-browser/policies/recommended \
           /etc/opt/edge/policies/recommended; do
    mkdir -p "$d" && printf '%s\n' "$NEWTAB" > "$d/tla-bootpaper.json" && chmod 644 "$d/tla-bootpaper.json"
  done
  # The background guard: a system service, so people can't stop it.
  fill "$HERE/tla-bootpaper-guard.service" /etc/systemd/system/tla-bootpaper-guard.service
  cp -f "$HERE/tla-bootpaper-guard.timer" /etc/systemd/system/
  systemctl daemon-reload
  systemctl enable --now tla-bootpaper-guard.timer >/dev/null 2>&1 || log "WARNING: couldn't start the background guard"
  # A copy installed for one person (3.5.5 in Intune's "User" context, or someone running the script without
  # sudo) would compete with this one, so it goes. Their choices (~/.config/tla-bootpaper) stay and carry over.
  for home in /home/* /root; do
    [ -d "$home/.local/share/tla-bootpaper" ] || continue
    rm -rf "$home/.local/share/tla-bootpaper"
    rm -f "$home/.config/autostart/tla-bootpaper.desktop" "$home/.local/share/applications/tla-bootpaper.desktop" \
          "$home/.local/share/applications/tla-bootpaper-report.desktop" \
          "$home/.local/share/applications/tla-bootpaper-care.desktop" \
          "$home/.config/systemd/user/tla-bootpaper-guard.service" "$home/.config/systemd/user/tla-bootpaper-guard.timer" \
          "$home/.config/systemd/user/default.target.wants/tla-bootpaper-guard.timer"
    log "Removed the copy installed just for $(basename "$home"); everyone now uses this one."
  done
else
  # 5.0: already using it (an update): the Welcome to TLA tour at their first login after the next startup.
  if [ "$WAS_INSTALLED" = 1 ] && [ ! -f "$CONF/tla-bootpaper/unbox.json" ]; then
    now="$(date +%s)"
    printf '{"state": "armed", "armed_at": %s, "armed_by": "update", "changed": %s}\n' "$now" "$now" \
      > "$CONF/tla-bootpaper/unbox.json"
  fi
  # Just for this person: the same names as the system-wide files, so these take their place.
  mkdir -p "$CONF/autostart" "$DATA/applications" "$CONF/systemd/user"
  fill "$HERE/tla-bootpaper-autostart.desktop" "$CONF/autostart/tla-bootpaper.desktop"
  fill "$HERE/tla-bootpaper.desktop" "$DATA/applications/tla-bootpaper.desktop"
  fill "$HERE/tla-bootpaper-report.desktop" "$DATA/applications/tla-bootpaper-report.desktop"   # (4.3)
  fill "$HERE/tla-bootpaper-care.desktop" "$DATA/applications/tla-bootpaper-care.desktop"       # (5.0)
  update-desktop-database "$DATA/applications" >/dev/null 2>&1 || true
  # The background guard as a systemd user timer (runs while they're signed in). If systemd can't be reached
  # right now, the login step switches it on.
  fill "$HERE/tla-bootpaper-guard.service" "$CONF/systemd/user/tla-bootpaper-guard.service"
  sed -e 's/^WantedBy=timers.target/WantedBy=default.target/' -e 's/^OnBootSec=30s/OnStartupSec=30s/' \
      "$HERE/tla-bootpaper-guard.timer" > "$CONF/systemd/user/tla-bootpaper-guard.timer"
  export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  systemctl --user daemon-reload >/dev/null 2>&1
  systemctl --user enable --now tla-bootpaper-guard.timer >/dev/null 2>&1 \
    || log "The background guard starts at the next login."
fi

# The intro videos download in the background (full quality, checked against their SHA-256). Clearing the
# "all there" marks makes the guard fetch any new video within a minute too, in case this download is cut short.
rm -f "$DEST/.videos-ok" "$DEST/.videos-checked"
( /usr/bin/python3 "$DEST/tla-bootpaper.py" sync-videos >/dev/null 2>&1 && touch "$DEST/.videos-ok" ) &

cp -f "$HERE/VERSION" "$DEST/VERSION"
log "Done. Takes effect at the next login."
exit 0
