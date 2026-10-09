#!/bin/bash
# TLA BootPaper for Linux - Intune Linux script. Installs or updates TLA BootPaper: the TLA intro video at login,
# the TLA backgrounds (desktop and lock screen, changed only in the TLA BootPaper app) and the TLA BootPaper app.
# Intune runs it as root ("Root" context; the computer's admin approves that once), and it installs for everyone
# on the computer. Run by someone without admin rights, it installs just for them instead. The bundle comes from
# the organization's GitHub repository and is only used if its SHA-256 matches the one below. When it's already installed, this does nothing.
VERSION="4.2"
URL="https://raw.githubusercontent.com/ebuskell-source/Default-wallpaper/main/TLA-BootPaper/linux/tla-bootpaper-linux-4.2.tar.gz"
SHA256="3a1292aceede1aa79a4d6cab6d754be4927d435bc77693eb26e609d59a1c34f7"

if [ "$(id -u)" = 0 ]; then
  DEST=/opt/tla-bootpaper
  have="$(cat "$DEST/VERSION" 2>/dev/null)"
  if [ -n "$have" ] && [ "$have" != "$VERSION" ] && [ "$(printf '%s\n%s\n' "$have" "$VERSION" | sort -V | tail -1)" = "$have" ] &&
     systemctl is-enabled --quiet tla-bootpaper-guard.timer 2>/dev/null; then
    echo "TLA BootPaper $have is installed for everyone (newer than this script's $VERSION)."; exit 0   # (4.1: never goes back)
  fi
  if [ "$have" = "$VERSION" ] && systemctl is-enabled --quiet tla-bootpaper-guard.timer 2>/dev/null; then
    echo "TLA BootPaper $VERSION is installed for everyone."; exit 0
  fi
else
  HOME="${HOME:-$(getent passwd "$(id -u)" | cut -d: -f6)}"
  # Already installed for everyone (by an administrator): that copy serves this person too.
  if [ -f /opt/tla-bootpaper/VERSION ]; then
    echo "TLA BootPaper $(cat /opt/tla-bootpaper/VERSION) is installed for everyone on this computer; an administrator updates it."
    exit 0
  fi
  DEST="${XDG_DATA_HOME:-$HOME/.local/share}/tla-bootpaper"
  if [ "$(cat "$DEST/VERSION" 2>/dev/null)" = "$VERSION" ] && [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/autostart/tla-bootpaper.desktop" ]; then
    echo "TLA BootPaper $VERSION is installed."; exit 0
  fi
fi
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
if ! curl -fsSL --connect-timeout 20 --max-time 600 "$URL" -o "$tmp/bundle.tar.gz"; then
  echo "Couldn't download TLA BootPaper (offline?). Intune will try again."; exit 1
fi
if [ "$(sha256sum "$tmp/bundle.tar.gz" | cut -d' ' -f1)" != "$SHA256" ]; then
  echo "The downloaded TLA BootPaper bundle doesn't match its SHA-256; not installing it."; exit 1
fi
tar -xzf "$tmp/bundle.tar.gz" -C "$tmp" && bash "$tmp/tla-bootpaper/install.sh"
