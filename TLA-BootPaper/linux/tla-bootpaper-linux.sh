#!/bin/bash
# TLA BootPaper for Linux - Intune Linux script (runs as root). Installs or updates TLA BootPaper: the TLA intro
# video at login, the TLA backgrounds (desktop and lock screen, changed only in the TLA BootPaper app) and the
# TLA BootPaper app. The bundle comes from the organization's GitHub repository and is only used if its SHA-256
# matches the one below. When it's already installed, this does nothing.
VERSION="3.4.2"
URL="https://raw.githubusercontent.com/ebuskell-source/Default-wallpaper/main/TLA-BootPaper/linux/tla-bootpaper-linux-3.4.2.tar.gz"
SHA256="a445cffea13c4547d403b0c79a33e781791578145f9636cd97d26cbab5fefaf8"

if [ "$(cat /opt/tla-bootpaper/VERSION 2>/dev/null)" = "$VERSION" ] && systemctl is-enabled --quiet tla-bootpaper-guard.timer 2>/dev/null; then
  echo "TLA BootPaper $VERSION is installed."
  exit 0
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
