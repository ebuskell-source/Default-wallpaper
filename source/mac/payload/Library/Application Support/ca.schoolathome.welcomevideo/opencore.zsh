#!/bin/zsh
# opencore.zsh (7.0) - a newer macOS for TLA's older Intel Macs, with OpenCore Legacy Patcher (OCLP, by Dortania).
# TLA Care offers it on Macs Apple stopped updating: macOS Sequoia (OCLP 2.5.1, recommended) or macOS Tahoe (OCLP
# 3.0.0-rc.5); on a 2019 iMac (Sequoia from Apple already), Tahoe only. Before choosing, the person sees what works
# differently on their Mac (opencore-issues.tsv, by its model's graphics: opencore-models.tsv). Out on Experimental
# only at first (WV_SINCE opencore); the organization can turn it off: "OpenCoreUpgrade" 0 in a configuration profile
# for ca.schoolathome.welcomevideo, or ORG_OpenCoreUpgrade=0 in org-defaults.zsh.
#
# Sourced (common.zsh loaded first) for oc_offer and oc_issues. Run as root ("run", by the LaunchDaemon
# ca.schoolathome.welcomevideo.opencore every 5 minutes, and straight away when TLA Care asks), it carries the
# upgrade through, one step per stage, picking up after each restart from Care/opencore:
#   prepare     the charger and free space; OCLP's package, downloaded from GitHub and checked against its SHA-256;
#               OpenCore built for this model and put on the internal disk's EFI partition, and made the startup
#               disk (bless); then a restart, announced 5 minutes ahead
#   fetch       (started up through OpenCore) Apple's full installer for the newest Sequoia or Tahoe, then
#               startosinstall, which restarts by itself 5 minutes later and installs (about an hour, several restarts)
#   installing  until the new macOS is running; then OCLP's patches (graphics, Wi-Fi, USB 1.1), and one more restart
#   done        afterwards, every 5 minutes: after a macOS update has taken the patches away, they go back on, and
#               one more restart is announced
#   failed      what went wrong is in the note (and the log); TLA Care can start again
# Care/opencore (root's, readable by all): key=value lines: target, oclp, phase, since, note, user, tries, build.

WV_DIR="/Library/Application Support/ca.schoolathome.welcomevideo"
OC_DIR="$WV_DIR/OpenCore"
OC_STATE="$WV_DIR/Care/opencore"
OC_APP="/Library/Application Support/Dortania/OpenCore-Patcher.app"
OC_BIN="$OC_APP/Contents/MacOS/OpenCore-Patcher"
OC_LOG="/Library/Logs/ca.schoolathome.welcomevideo.log"
# The OCLP releases used: version, the package's SHA-256 (checked before installing), and the macOS it brings.
typeset -gA OC_VERSION=(sequoia 2.5.1 tahoe 3.0.0-rc.5)
typeset -gA OC_SHA=(sequoia e4b65f633f97818b26135ba19e528e59dd100a986cf11bdcde62ef51f1e1603a
                    tahoe 0a604e738b83ca36a7392cad20e329057033122261db9dc4d8e9135fc5d8430c)
typeset -gA OC_MAJOR=(sequoia 15 tahoe 26)
typeset -gA OC_NAME=(sequoia "macOS Sequoia" tahoe "macOS Tahoe")
typeset -gA OC_FREE_GB=(sequoia 45 tahoe 55)   # (the installer, about 15 GB or 20 GB, and room for it to install)
# Macs Apple itself updates: to Sequoia, and to Tahoe (Intel).
OC_NATIVE_SEQUOIA=(MacBookPro15,1 MacBookPro15,2 MacBookPro15,3 MacBookPro15,4 MacBookPro16,1 MacBookPro16,2 MacBookPro16,3
                   MacBookPro16,4 MacBookAir9,1 iMac19,1 iMac19,2 iMac20,1 iMac20,2 iMacPro1,1 Macmini8,1 MacPro7,1)
OC_NATIVE_TAHOE=(MacBookPro16,1 MacBookPro16,2 MacBookPro16,4 iMac20,1 iMac20,2 MacPro7,1)
OC_TOUCHBAR=(MacBookPro13,2 MacBookPro13,3 MacBookPro14,2 MacBookPro14,3)

oc_log() { print -r -- "$(/bin/date '+%Y-%m-%d %H:%M:%S') OpenCore: $*" >> "$OC_LOG" }
oc_model() { [[ -n "$TB_TEST_MODEL" ]] && print -r -- "$TB_TEST_MODEL" || /usr/sbin/sysctl -n hw.model 2>/dev/null }
oc_row() { /usr/bin/awk -F'\t' -v m="$1" '$1 == m { print; exit }' "$WV_DIR/opencore-models.tsv" 2>/dev/null }
oc_macos_major() { local v; v="$(/usr/bin/sw_vers -productVersion 2>/dev/null)"; print -r -- "${v%%.*}" }
oc_ram_gb() { print $(( $(/usr/sbin/sysctl -n hw.memsize 2>/dev/null || print 0) / 1073741824 )) }
oc_free_gb() { /bin/df -g /System/Volumes/Data 2>/dev/null | /usr/bin/awk 'NR == 2 { print $4 }' }
oc_through_opencore() { /usr/sbin/nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:OCLP-Version >/dev/null 2>&1 }
oc_allowed() {
  local o; o="$(/usr/bin/defaults read "/Library/Managed Preferences/ca.schoolathome.welcomevideo" OpenCoreUpgrade 2>/dev/null)"
  [[ -n "$o" ]] || o="$ORG_OpenCoreUpgrade"
  [[ "$o" != (0|false) ]]
}
oc_get() { /usr/bin/awk -F= -v k="$1" '$1 == k { print substr($0, length(k) + 2); exit }' "$OC_STATE" 2>/dev/null }

# What TLA Care offers this Mac: "offer<TAB><versions, recommended first>" (sequoia tahoe | tahoe), or
# "none<TAB><why, for the person>", or nothing at all (Apple silicon, Macs Apple updates to Tahoe, turned off).
oc_offer() {
  [[ -n "$TB_TEST_MODEL" || "$(/usr/bin/uname -m)" == x86_64 ]] || return 0
  { [[ -n "$OC_ROOT" ]] || wv_released opencore; } && oc_allowed || return 0   # (root: the person who asked had it)
  local m row major; m="$(oc_model)"; row="$(oc_row "$m")"; major="$(oc_macos_major)"
  [[ -n "$TB_TEST_MACOS" ]] && major="$TB_TEST_MACOS"
  (( ${OC_NATIVE_TAHOE[(Ie)$m]} )) && return 0
  local -a f=("${(@ps:\t:)row}")
  if [[ -z "$row" || "${f[5]}" != 1 ]]; then
    (( ${OC_NATIVE_SEQUOIA[(Ie)$m]} )) && return 0
    print -r -- "none	OpenCore Legacy Patcher doesn't work on this model${f[2]:+ (${f[2]})}: on Macs with Apple's T2 chip, its makers say macOS stops with an error while starting up, before the installer appears."
    return 0
  fi
  if (( $(oc_ram_gb) < 3 )); then
    print -r -- "none	This Mac has $(oc_ram_gb) GB of memory: Sequoia and Tahoe need at least 3 GB to install."; return 0
  fi
  if (( ${OC_NATIVE_SEQUOIA[(Ie)$m]} )) || (( major >= 15 )); then
    (( major >= 26 )) && return 0
    print -r -- "offer	tahoe"
  else
    [[ "${f[4]}" == 1 ]] && print -r -- "offer	sequoia tahoe" || print -r -- "offer	tahoe"
  fi
}
# What works differently on this Mac with <version>, one line each.
oc_issues() {   # oc_issues sequoia|tahoe
  local m row; m="$(oc_model)"; row="$(oc_row "$m")"
  local -a f=("${(@ps:\t:)row}"); local -a who=(all ${(s:,:)f[3]})   # (two lines: f has to be set first)
  [[ "${f[6]}" == 1 ]] && who+=(usb11)
  (( ${OC_TOUCHBAR[(Ie)$m]} )) && who+=(touchbar)
  /usr/bin/awk -F'\t' -v who=" ${who[*]} " -v os="$1" '!/^#/ && NF >= 3 && index(who, " " $1 " ") && ($2 == "all" || $2 == os) { print $3 }' \
    "$WV_DIR/opencore-issues.tsv" | /usr/bin/awk '!seen[$0]++'
}
oc_model_name() { local row; row="$(oc_row "$(oc_model)")"; local -a f=("${(@ps:\t:)row}"); print -r -- "${f[2]:-this Mac}" }

# ---- Root: carrying it through ----------------------------------------------------------------------------------
oc_set() {   # oc_set key value [key value...]
  (( EUID == 0 )) || return 1
  local -A s; local k v line
  if [[ -f "$OC_STATE" ]]; then
    while IFS= read -r line; do [[ "$line" == *=* ]] && s[${line%%=*}]="${line#*=}"; done < "$OC_STATE"
  fi
  while (( $# >= 2 )); do s[$1]="$2"; shift 2; done
  /bin/mkdir -p "$WV_DIR/Care"
  { for k in ${(ok)s}; do print -r -- "$k=${s[$k]}"; done } > "$OC_STATE.$$" && /bin/chmod 644 "$OC_STATE.$$" && /bin/mv -f "$OC_STATE.$$" "$OC_STATE"
}
oc_phase() { oc_set phase "$1" since "$(/bin/date +%s)" note "$2" tries 0; oc_log "$1: $2" }
oc_fail() { oc_set phase failed note "$1"; oc_log "failed: $1"; exit 1 }
oc_console_user() { local u; u="$(/usr/bin/stat -f %Su /dev/console 2>/dev/null)"; [[ -n "$u" && "$u" != (root|loginwindow) ]] && print -r -- "$u" }
# A message for whoever is using the Mac, and a restart 5 minutes later (or now, if they click Restart now).
oc_restart_soon() {   # oc_restart_soon <why>
  local u uid; u="$(oc_console_user)"
  /sbin/shutdown -r +5 "TLA BootPaper: $1" >/dev/null 2>&1 &!
  if [[ -n "$u" ]]; then
    uid="$(/usr/bin/id -u "$u")"
    /bin/launchctl asuser "$uid" /usr/bin/sudo -u "$u" /usr/bin/osascript - "$1" >/dev/null 2>&1 <<'EOF' &!
on run argv
  try
    activate
    set r to display dialog ((item 1 of argv) & return & return & "Your Mac restarts in 5 minutes. Save your work. Keep it plugged in until the upgrade is finished.") buttons {"OK", "Restart now"} default button "OK" with title "TLA BootPaper: macOS upgrade" giving up after 280
    if button returned of r is "Restart now" then tell application "System Events" to restart
  end try
end run
EOF
  fi
}
oc_on_charger() { [[ -n "$TB_TEST" ]] && return 0; ! /usr/bin/pmset -g batt 2>/dev/null | /usr/bin/grep -q InternalBattery || /usr/bin/pmset -g batt | /usr/bin/grep -q "AC Power" }

# The internal disk's EFI partition (e.g. disk0s1), where OpenCore goes.
oc_efi_partition() {
  local store whole p
  store="$(/usr/sbin/diskutil info / 2>/dev/null | /usr/bin/awk -F': *' '/APFS Physical Store/ { print $2; exit }')"
  [[ -n "$store" ]] || store="$(/usr/sbin/diskutil info / 2>/dev/null | /usr/bin/awk -F': *' '/Device Identifier/ { print $2; exit }')"
  whole="$(/usr/sbin/diskutil info "$store" 2>/dev/null | /usr/bin/awk -F': *' '/Part of Whole/ { print $2; exit }')"
  [[ -n "$whole" ]] || return 1
  for p in ${whole}s1 ${whole}s2; do
    /usr/sbin/diskutil info "$p" 2>/dev/null | /usr/bin/grep -Eq 'Partition Type: *EFI' && { print -r -- "$p"; return 0; }
  done
  return 1
}

# OpenCore, built by OCLP for <model>, copied to OpenCore/Build (prints that folder). OCLP builds it in a temporary
# folder that it deletes as it quits, so it's paused (SIGSTOP) once its log says where the build is, copied, and then
# ended, with its payloads disk image detached and the temporary folder removed.
oc_build() {   # oc_build <model>
  local mark="$OC_DIR/.build-started" logs="$HOME/Library/Logs/Dortania" built="" lf root i
  /usr/bin/touch "$mark"; /bin/sleep 1
  PYTHONUNBUFFERED=1 "$OC_BIN" --build --model "$1" >> "$OC_LOG" 2>&1 &
  local -i pid=$!
  for (( i = 0; i < 3000; i++ )); do
    for lf in "$logs"/OpenCore-Patcher_*.log(N.om[1,3]); do
      [[ "$lf" -nt "$mark" ]] || continue
      built="$(/usr/bin/awk '/has been built at:/ { getline; if (match($0, /\/[^ ]*\/Build-Folder\/OpenCore-Build/)) print substr($0, RSTART, RLENGTH); exit }' "$lf")"
      [[ -n "$built" ]] && break
    done
    [[ -n "$built" ]] && break
    kill -0 $pid 2>/dev/null || break
    /bin/sleep 0.2
  done
  [[ -n "$built" ]] && kill -STOP $pid 2>/dev/null
  local out="$OC_DIR/Build"
  /bin/rm -rf "$out"
  if [[ -d "$built/EFI/OC" ]]; then /usr/bin/ditto "$built" "$out"; fi
  kill -KILL $pid 2>/dev/null; wait $pid 2>/dev/null
  root="${built%/Build-Folder/*}"
  if [[ -n "$built" && "$root" == /*tmp* && -d "$root" ]]; then
    /usr/bin/hdiutil detach -force "$root/payloads" >/dev/null 2>&1; /bin/rm -rf "$root"
  fi
  oc_log "built OpenCore for $1 (${built:-no build folder})."
  [[ -d "$out/EFI/OC" ]] || return 1
  print -r -- "$out"
}

oc_prepare() {
  local target; target="$(oc_get target)"
  [[ -n "${OC_VERSION[$target]}" ]] || oc_fail "Nothing to upgrade to."
  local m; m="$(oc_model)"
  [[ "$(oc_offer)" == "offer	"*"$target"* ]] || oc_fail "$(oc_model_name) can't get ${OC_NAME[$target]} this way."
  oc_on_charger || { oc_set note "Waiting for the charger: plug this Mac in to continue."; return 0; }
  local -i free; free=$(oc_free_gb)
  (( free >= OC_FREE_GB[$target] )) || { oc_set note "Waiting for space: ${OC_NAME[$target]} needs ${OC_FREE_GB[$target]} GB free and there's $free GB. TLA Care can help free some up."; return 0; }
  # OCLP's package (checked against its SHA-256).
  local v="${OC_VERSION[$target]}" pkg="$OC_DIR/OpenCore-Patcher-${OC_VERSION[$target]}.pkg"
  /bin/mkdir -p "$OC_DIR"; /bin/chmod 700 "$OC_DIR"
  if [[ "$(/usr/bin/shasum -a 256 "$pkg" 2>/dev/null | /usr/bin/awk '{ print $1 }')" != "${OC_SHA[$target]}" ]]; then
    oc_set note "Downloading OpenCore Legacy Patcher $v (about 1 GB)."
    /usr/bin/curl -fsSL --connect-timeout 20 --max-time 3600 -o "$pkg.part" \
      "https://github.com/dortania/OpenCore-Legacy-Patcher/releases/download/$v/OpenCore-Patcher.pkg" || { /bin/rm -f "$pkg.part"; oc_set note "Couldn't download OpenCore Legacy Patcher yet; trying again in 5 minutes."; return 0; }
    [[ "$(/usr/bin/shasum -a 256 "$pkg.part" | /usr/bin/awk '{ print $1 }')" == "${OC_SHA[$target]}" ]] || { /bin/rm -f "$pkg.part"; oc_fail "The OpenCore Legacy Patcher download wasn't the expected file (its SHA-256 didn't match), so it wasn't used."; }
    /bin/mv -f "$pkg.part" "$pkg"
  fi
  if [[ "$(/usr/bin/defaults read "$OC_APP/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null)" != "$v" ]]; then
    oc_set note "Installing OpenCore Legacy Patcher $v."
    /usr/sbin/installer -pkg "$pkg" -target / >> "$OC_LOG" 2>&1 || oc_fail "OpenCore Legacy Patcher $v didn't install (see the log)."
  fi
  # OpenCore, built for this model, onto the internal disk's EFI partition.
  oc_set note "Building OpenCore for $(oc_model_name)."
  local built; built="$(oc_build "$m")" || oc_fail "OpenCore Legacy Patcher couldn't build OpenCore for $m (see the log)."
  [[ -n "$TB_TEST" ]] && { oc_set note "Built (test: not installed)." built "$built"; return 0; }
  local efi mnt; efi="$(oc_efi_partition)" || oc_fail "Couldn't find the internal disk's EFI partition."
  /usr/sbin/diskutil mount "$efi" >/dev/null 2>&1 || oc_fail "Couldn't mount the EFI partition ($efi)."
  mnt="$(/usr/sbin/diskutil info "$efi" | /usr/bin/awk -F': *' '/Mount Point/ { print $2; exit }')"
  [[ -d "$mnt" ]] || oc_fail "The EFI partition ($efi) didn't mount."
  /bin/rm -rf "$mnt/EFI/OC" "$mnt/System" "$mnt/boot.efi"
  /bin/mkdir -p "$mnt/EFI"
  /bin/cp -R "$built/EFI/OC" "$mnt/EFI/OC" && /bin/cp -R "$built/System" "$mnt/System" || oc_fail "Couldn't copy OpenCore onto the EFI partition."
  [[ -f "$built/boot.efi" ]] && /bin/cp "$built/boot.efi" "$mnt/boot.efi"
  local blessed=1
  /usr/sbin/bless --mount "$mnt" --setBoot --file "$mnt/System/Library/CoreServices/boot.efi" >> "$OC_LOG" 2>&1 || blessed=0
  /usr/sbin/diskutil unmount "$mnt" >/dev/null 2>&1
  oc_set blessed $blessed
  oc_phase fetch "OpenCore is on this Mac. After the restart, ${OC_NAME[$target]} downloads (about $(( OC_FREE_GB[$target] / 3 )) GB) and installs."
  if (( blessed )); then oc_restart_soon "The ${OC_NAME[$target]} upgrade continues after a restart."
  else oc_restart_soon "The ${OC_NAME[$target]} upgrade continues after a restart. When the Mac turns off, hold the Option (alt) key as it starts, and pick \"EFI Boot\" while holding Control."; fi
}

oc_fetch() {
  local target; target="$(oc_get target)"
  if ! oc_through_opencore; then
    local -i tries=$(( $(oc_get tries) + 1 )); oc_set tries $tries
    oc_set note "Waiting for this Mac to start up through OpenCore: restart it, hold the Option (alt) key, and pick \"EFI Boot\" while holding Control."
    return 0
  fi
  local want="${OC_MAJOR[$target]}" ver="" line app
  oc_on_charger || { oc_set note "Waiting for the charger: plug this Mac in to continue."; return 0; }
  for line in "${(@f)$(/usr/sbin/softwareupdate --list-full-installers 2>/dev/null)}"; do
    [[ "$line" =~ 'Version: ([0-9]+)\.([0-9.]+)' && "${match[1]}" == "$want" && -z "$ver" ]] && ver="${match[1]}.${match[2]}"
  done
  [[ -n "$ver" ]] || { oc_set note "Waiting for Apple's list of installers (it didn't offer ${OC_NAME[$target]} yet)."; return 0; }
  oc_set note "Downloading ${OC_NAME[$target]} $ver from Apple. This takes a while."
  /usr/sbin/softwareupdate --fetch-full-installer --full-installer-version "$ver" >> "$OC_LOG" 2>&1 || { oc_set note "The ${OC_NAME[$target]} download stopped; trying again in 5 minutes."; return 0; }
  app="$(/bin/ls -d "/Applications/Install ${OC_NAME[$target]}.app" 2>/dev/null)"
  [[ -x "$app/Contents/Resources/startosinstall" ]] || oc_fail "The ${OC_NAME[$target]} installer isn't in Applications."
  oc_phase installing "Installing ${OC_NAME[$target]} $ver: the Mac restarts by itself several times. Keep it plugged in."
  oc_restart_soon "${OC_NAME[$target]} is ready to install. It takes about an hour, with several restarts."
  /usr/bin/pkill -f 'shutdown -r' 2>/dev/null   # (startosinstall restarts it itself, after the same 5 minutes)
  "$app/Contents/Resources/startosinstall" --agreetolicense --forcequitapps --nointeraction --rebootdelay 300 >> "$OC_LOG" 2>&1 &!
}

oc_patch_needed() { [[ ! -f /System/Library/CoreServices/OpenCore-Legacy-Patcher.plist ]] }
oc_installing() {
  local target; target="$(oc_get target)"
  (( $(oc_macos_major) >= OC_MAJOR[$target] )) || {
    (( $(/bin/date +%s) - $(oc_get since) > 3 * 86400 )) && oc_fail "${OC_NAME[$target]} didn't finish installing within 3 days."
    return 0; }
  oc_patch
  oc_phase done "${OC_NAME[$target]} $(/usr/bin/sw_vers -productVersion) is installed."
}
# OCLP's patches for this Mac (graphics, Wi-Fi, USB 1.1), after installing and after each macOS update.
oc_patch() {
  local build; build="$(/usr/bin/sw_vers -buildVersion)"
  oc_patch_needed || { oc_set build "$build"; return 0; }
  [[ "$(oc_get build)" == "$build" ]] && return 0      # (tried already on this macOS: not again every 5 minutes)
  oc_set build "$build" note "Putting OpenCore Legacy Patcher's patches on."
  "$OC_BIN" --patch_sys_vol >> "$OC_LOG" 2>&1
  if oc_patch_needed; then oc_log "patches: OCLP put none on for $build (none needed, or it couldn't: see above)."
  else oc_log "patches: on for $build."; oc_restart_soon "Graphics and Wi-Fi patches for this Mac are on; a restart finishes them."; fi
}

oc_run() {
  (( EUID == 0 )) || { print -r -- "opencore.zsh run: needs root" >&2; exit 1; }
  [[ -f "$OC_STATE" ]] || exit 0
  case "$(oc_get phase)" in
    prepare)    oc_prepare ;;
    fetch)      oc_fetch ;;
    installing) oc_installing ;;
    done)       oc_through_opencore && oc_patch ;;
  esac
}

if [[ "${ZSH_EVAL_CONTEXT}" == toplevel && "$1" == run ]]; then
  OC_ROOT=1
  source "$WV_DIR/common.zsh" >/dev/null 2>&1
  [[ -f "$WV_DIR/org-defaults.zsh" ]] && source "$WV_DIR/org-defaults.zsh" >/dev/null 2>&1
  oc_run
fi
