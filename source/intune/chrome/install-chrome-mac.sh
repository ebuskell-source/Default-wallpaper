#!/bin/zsh
# install-chrome-mac.sh - TLA: puts Google Chrome on this Mac if it isn't there (Intune shell script, as root).
# Chrome then keeps itself up to date. Only installs a package signed by Google (Team ID EQHXZ8M8AV).
[[ -d "/Applications/Google Chrome.app" ]] && { echo "Chrome already installed"; exit 0; }
tmp="$(/usr/bin/mktemp -d /private/tmp/chrome.XXXXXX)"; trap '/bin/rm -rf "$tmp"' EXIT
/usr/bin/curl -fsSL --max-time 600 -o "$tmp/chrome.pkg" "https://dl.google.com/dl/chrome/mac/universal/stable/gcem/GoogleChrome.pkg" || { echo "download failed"; exit 1; }
team="$(/usr/sbin/pkgutil --check-signature "$tmp/chrome.pkg" | /usr/bin/awk -F'[()]' '/Developer ID Installer/ { print $2; exit }')"
[[ "$team" == EQHXZ8M8AV ]] || { echo "signature check failed ($team)"; exit 1; }
/usr/sbin/installer -pkg "$tmp/chrome.pkg" -target / && echo "Chrome installed"
