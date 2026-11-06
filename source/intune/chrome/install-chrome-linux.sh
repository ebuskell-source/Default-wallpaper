#!/bin/bash
# install-chrome-linux.sh - TLA: puts Google Chrome on this Ubuntu computer if it isn't there (Intune Linux script,
# as root). Adds Google's signed apt repository, so Chrome updates with the computer's normal updates.
command -v google-chrome-stable >/dev/null && { echo "Chrome already installed"; exit 0; }
set -e
export DEBIAN_FRONTEND=noninteractive
install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor --yes -o /etc/apt/keyrings/google-chrome.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
apt-get update -qq
apt-get install -y -qq google-chrome-stable
echo "Chrome installed"
