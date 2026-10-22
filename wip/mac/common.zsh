# common.zsh
# Shared by play-welcome-video.zsh (runs at every login) and settings.zsh (the TLA BootPaper app).
#
#   Organization defaults: org-defaults.zsh (in this folder, installed by the package)
#   Each person's choices: defaults domain ca.schoolathome.welcomevideo (in their Library/Preferences)
#   What has happened:     the same domain, keys starting with "State"
#
# A person's own choice wins over the organization default, unless ORG_UsersCanChange is 0.

WV_DIR="/Library/Application Support/ca.schoolathome.welcomevideo"
WV_DOMAIN="ca.schoolathome.welcomevideo"
WV_RELEASE="5.5.5"                     # this package's version (4.3: what people see also depends on their release channel)
WV_DIALOG="/usr/local/bin/dialog"      # swiftDialog
WV_APP="/Applications/TLA BootPaper.app"
WV_ICON="$WV_DIR/AppIcon.png"
WV_HELPDESK="helpdesk@schoolathome.ca"

WV_SETTINGS=(Enabled PlayWhen Sound AllowSkip Background Video QuietMode QuietStart QuietEnd QuietDays PreferredName
             WallpaperFit LockBackground TempBackground TempUntil Channel
             LightDark Screensaver CareReminders Greeting)   # (5.5.5: Greeting, on or off, keeping their name)
# Light and dark (5.0): every background has a second picture for the other mode (5.1: Underwater too; not the
# Experimental one). The value is the mode of that extra picture (Backgrounds/<id>-<mode>.jpg, thumbs/<id>-<mode>.jpg);
# the original is the other one. The intro videos in WV_BOTH_VIDEOS have a second video for that mode as well
# (Videos/<id>-<mode>.mp4), which plays while the Mac is in that mode; the others have one video for both.
WV_LIGHTDARK=(Auto Light Dark)
WV_LIGHTDARK_LABELS=("Match my light or dark mode" "Always light" "Always dark")
typeset -gA WV_VARIANTS=(microsoft dark liquid-glass dark frutiger-aero dark solarpunk dark rainy dark claymation dark
                         blocks dark bricks dark pixel dark anime dark sky-city dark tla dark penguins light code light
                         space light ocean dark beach dark fall dark christmas dark easter dark)
WV_BOTH_VIDEOS=(blocks bricks frutiger-aero liquid-glass microsoft penguins anime beach pixel claymation)   # (5.1: Bricks' dark and Penguins' light; 5.4: Anime's dark and Beach; 5.4.5: 8-Bit's and Claymation's dark)
# (5.4) True when this background's second intro video is out on this person's channel too.
wv_both_videos() { (( ${WV_BOTH_VIDEOS[(Ie)$1]} )) && wv_released "$1-${WV_VARIANTS[$1]}" }
# 4.2: how the desktop picture fits the screen, and how long a pick lasts ("Use my pick"; not saved: each time the
# app opens, a pick is for good unless they choose otherwise).
WV_FITS=(Fill Fit)
WV_FIT_LABELS=("Fill the screen" "Show the whole picture")
WV_PICKFOR=(Always Tomorrow Week)
WV_PICKFOR_LABELS=("From now on" "Just for today" "For one week")
# Quiet hours (4.0): the intro video plays without sound during the hours (and days) the person sets. Off
# unless they turn it on. (Macs don't offer "while Do Not Disturb is on": macOS doesn't reliably let other
# programs see whether a Focus is on.)
WV_QUIET=(Off Hours)
WV_QUIET_LABELS=("Don't mute it" "Mute it during these hours")
WV_DAYS=(Mon Tue Wed Thu Fri Sat Sun)
WV_NAME_MAX=30
# Seasonal themes (4.0): during its season, everyone still on the organization's default background gets the
# seasonal one instead. Picking a background yourself keeps yours. No intro video of their own: the default
# background's video plays.
WV_SEASONAL=(fall christmas easter)
WV_SEASONAL_NAMES=("Fall" "Christmas" "Easter")
WV_SEASON_ENDS=("November 30" "January 6" "Easter Monday")
WV_PLAYWHEN=(EverySignIn OncePerDay AfterUpdate FirstTime)
# No commas in these labels: swiftDialog uses commas to separate the options.
WV_PLAYWHEN_LABELS=("Every time I log in" "Once a day (the first time I log in)"
                    "Only after macOS installs an update" "Only once (and again when there's a new video)")
# Backgrounds (Backgrounds/<id>.jpg). Ones with no intro video yet (not in WV_VIDEOS) come last, and the app
# marks them "intro video coming soon". macOS shows the desktop background on the lock screen too.
# 5.1: "experimental", the Experimental channel's own background (beta testers only, no intro video of its own).
WV_BACKGROUNDS=(microsoft liquid-glass penguins code frutiger-aero solarpunk rainy space ocean beach claymation blocks bricks pixel anime sky-city tla experimental)
WV_BACKGROUND_NAMES=("Microsoft" "Liquid Glass" "Penguins" "Code" "Frutiger Aero" "Solarpunk" "Rainy" "Space" "Underwater" "Beach" "Claymation" "Blocks" "Bricks" "8-Bit" "Anime" "Sky City" "TLA Classic" "Experimental")
# Intro videos (Videos/<id>.mp4). "match" = the video that goes with the person's desktop background.
# "surprise" (4.0) = a different one each time it plays.
WV_VIDEOS=(match surprise microsoft liquid-glass penguins code frutiger-aero solarpunk rainy space ocean beach claymation blocks bricks pixel anime sky-city tla frutiger-aero-v2 liquid-glass-original microsoft-original)
WV_VIDEO_NAMES=("Match my desktop background" "Surprise me (a different one each time)" "Microsoft" "Liquid Glass" "Penguins" "Code" "Frutiger Aero" "Solarpunk" "Rainy" "Space" "Underwater" "Beach" "Claymation" "Blocks" "Bricks" "8-Bit" "Anime" "Sky City" "TLA Classic" "Frutiger Aero (newer version)" "Liquid Glass (original)" "Microsoft (original)")
# Release channels (4.3). Each release is marked Stable or Experimental. Everyone gets the same package from
# Intune, but new backgrounds, videos and features only show for people on a channel that has their release:
# Experimental first, Stable once it's been tried. People pick their channel in the app (organization default:
# Stable). WV_SINCE: the release that brought something; anything not listed has been out for longer.
WV_CHANNELS=(stable experimental)
WV_CHANNEL_NAMES=("Stable" "Experimental")
typeset -gA WV_CHANNEL_MARKS=(stable 5.3 experimental 5.5.5)   # as marked when this package was made (5.5.5: Experimental first)
typeset -gA WV_SINCE=(sky-city 4.3 report 4.3 lightdark 5.0 screensaver 5.0 calls 5.0 care 5.0 tour 5.0 connect 5.2.5
                      beach 5.4 anime-dark 5.4 pixel-dark 5.4.5 claymation-dark 5.4.5
                      greeting-styles 5.5.5 greeting-switch 5.5.5)   # (5.4: "<id>-<mode>" = that background's second intro video)
# Only ever on one channel (5.1), even once that release reaches Stable: the Experimental background.
typeset -gA WV_CHANNEL_ONLY=(experimental experimental)
# The newest marks, from channels.json in the organization's GitHub repository (sync-videos.zsh, as root).
WV_CHANNEL_FILE="$WV_DIR/channels.tsv"

source "$WV_DIR/org-defaults.zsh"

# A short log in the person's own Library/Logs ("TLA BootPaper.log"), for troubleshooting.
wv_log() {
  local f="$HOME/Library/Logs/TLA BootPaper.log"
  [[ -f "$f" && $(/usr/bin/stat -f %z "$f" 2>/dev/null || echo 0) -gt 65536 ]] && /bin/mv -f "$f" "$f.old"
  print -r -- "$(/bin/date '+%Y-%m-%d %H:%M:%S') $*" >> "$f" 2>/dev/null
}

wv_get()   {
  if (( WV_CACHED )) && [[ -z "${WV_OTHER[$1]+x}" ]]; then
    [[ -n "${WV_CACHE[$1]+x}" ]] || return 1; print -r -- "${WV_CACHE[$1]}"; return 0
  fi
  /usr/bin/defaults read "$WV_DOMAIN" "$1" 2>/dev/null
}
wv_set()   { (( WV_CACHED )) && WV_CACHE[$1]="$2"; /usr/bin/defaults write "$WV_DOMAIN" "$1" -string "$2" }
wv_unset() { (( WV_CACHED )) && unset "WV_CACHE[$1]"; /usr/bin/defaults delete "$WV_DOMAIN" "$1" 2>/dev/null; return 0 }

# The login script reads all of a person's settings at once (one call instead of one per setting), so the
# video starts sooner. Only plain strings are cached; anything else is read the normal way.
typeset -gA WV_CACHE WV_OTHER; typeset -g WV_CACHED=0
wv_load_settings() {
  local line key="" v
  for line in "${(@f)$(/usr/bin/defaults export "$WV_DOMAIN" - 2>/dev/null)}"; do
    if [[ "$line" == *"<key>"*"</key>"* ]]; then
      key="${${line#*<key>}%</key>*}"
    elif [[ -n "$key" && "$line" == *"<string>"*"</string>"* ]]; then
      v="${${line#*<string>}%</string>*}"
      v="${v//&lt;/<}"; v="${v//&gt;/>}"; v="${v//&quot;/\"}"; v="${v//&amp;/&}"
      WV_CACHE[$key]="$v"; key=""
    elif [[ -n "$key" ]]; then
      WV_OTHER[$key]=1; key=""          # a number, true/false, list...: read normally
    fi
  done
  WV_CACHED=1
}

wv_valid() {   # wv_valid <setting> <value>
  case "$1" in
    PlayWhen)   (( ${WV_PLAYWHEN[(Ie)$2]} )) ;;
    Background) (( ${WV_BACKGROUNDS[(Ie)$2]} )) || [[ "$2" == surprise ]] ;;
    Video)      (( ${WV_VIDEOS[(Ie)$2]} )) ;;
    QuietMode)  (( ${WV_QUIET[(Ie)$2]} )) ;;
    QuietStart|QuietEnd) [[ "$2" == ([01][0-9]|2[0-3]):(00|15|30|45) ]] ;;
    QuietDays)  local d; for d in ${(s:,:)2}; do (( ${WV_DAYS[(Ie)$d]} )) || return 1; done; return 0 ;;
    PreferredName) (( ${#2} <= WV_NAME_MAX )) && [[ "$2" != *[[:cntrl:]]* ]] ;;
    WallpaperFit)   (( ${WV_FITS[(Ie)$2]} )) ;;
    LockBackground) [[ "$2" == same ]] || (( ${WV_BACKGROUNDS[(Ie)$2]} )) ;;
    TempBackground) (( ${WV_BACKGROUNDS[(Ie)$2]} )) ;;
    TempUntil)      [[ "$2" == <->-<->-<-> ]] ;;
    Channel)        (( ${WV_CHANNELS[(Ie)$2]} )) ;;
    LightDark)      (( ${WV_LIGHTDARK[(Ie)$2]} )) ;;
    *)          [[ "$2" == (0|1) ]] ;;
  esac
}

wv_org() {     # the organization's value
  local v; v="${(P)${:-ORG_$1}}"
  wv_valid "$1" "$v" && [[ -n "$v" || "$1" == PreferredName ]] && { print -r -- "$v"; return }
  case "$1" in
    PlayWhen) print EverySignIn ;; Background) print liquid-glass ;; Video) print match ;; AllowSkip) print 0 ;;
    QuietMode) print Off ;; QuietStart) print 08:30 ;; QuietEnd) print 15:00 ;; QuietDays) print Mon,Tue,Wed,Thu,Fri ;;
    PreferredName|TempBackground|TempUntil) print -r -- "" ;;
    WallpaperFit) print Fill ;; LockBackground) print same ;; Channel) print stable ;; LightDark) print Auto ;;
    *) print 1 ;;
  esac
}

wv_users_can_change() { [[ "$ORG_UsersCanChange" != 0 ]] }

wv_setting() { # the value in effect for this person
  local v
  if wv_users_can_change; then
    # (Only what they've actually set: an empty name or no quiet days is a choice, a missing value isn't.)
    # 4.1: Frutiger Aero's original video is "Frutiger Aero" again, so an earlier choice of the original keeps it.
    # 4.3: a background or video they picked that isn't out on their release channel counts as not picked.
    v="$(wv_get "$1")" && { [[ "$1" == Video && "$v" == frutiger-aero-original ]] && v=frutiger-aero; wv_valid "$1" "$v" } &&
      { [[ "$1" != (Background|Video|LockBackground|TempBackground) ]] || wv_released "$v" } &&
      { print -r -- "$v"; return }
  fi
  wv_org "$1"
}

# Save a choice. Matching the organization default removes it, so later default changes still apply.
# A background picked in the app is always kept (even the default one): it's what tells the seasonal themes
# this person chose their own.
wv_save() {
  if [[ "$1" != Background && "$2" == "$(wv_org "$1")" ]]; then wv_unset "$1"; else wv_set "$1" "$2"; fi
}

wv_has_video() { (( ${WV_VIDEOS[(Ie)$1]} )) && [[ "$1" != (match|surprise) ]] }   # wv_has_video <background id>

# ---- Release channels (4.3) ---------------------------------------------------------------------------------
wv_vkey() {   # '4.3' -> 0004000300000000, so versions compare as text ('4.3' = '4.3.0', '4.2.5' < '4.3')
  local -a p=(${(s:.:)1} 0 0 0 0)
  printf '%04d%04d%04d%04d' $(( 10#${p[1]} )) $(( 10#${p[2]} )) $(( 10#${p[3]} )) $(( 10#${p[4]} ))
}
wv_version_ok() { [[ "$1" =~ '^[0-9]{1,4}(\.[0-9]{1,4}){0,3}$' ]] }
wv_version_gt() { [[ "$(wv_vkey "$1")" > "$(wv_vkey "$2")" ]] }   # wv_version_gt <a> <b>: a is newer
wv_channel() { wv_setting Channel }
# The newest release on a channel (this person's by default). Experimental always has at least what Stable has.
wv_channel_release() {
  local ch="${1:-$(wv_channel)}" k v
  typeset -A mark=(stable "${WV_CHANNEL_MARKS[stable]}" experimental "${WV_CHANNEL_MARKS[experimental]}")
  if [[ -f "$WV_CHANNEL_FILE" ]]; then
    while IFS=$'\t' read -r k v; do
      [[ "$k" == (stable|experimental) ]] && wv_version_ok "$v" && mark[$k]="$v"
    done < "$WV_CHANNEL_FILE"
  fi
  if [[ "$ch" == experimental ]] && wv_version_gt "${mark[stable]}" "${mark[experimental]}"; then print -r -- "${mark[stable]}"
  else print -r -- "${mark[$ch]}"; fi
}
# The version this person sees: their channel's release, or this package's if that's older.
wv_shown_release() {
  local r; r="$(wv_channel_release)"
  if wv_version_gt "$WV_RELEASE" "$r"; then print -r -- "$r"; else print -r -- "$WV_RELEASE"; fi
}
wv_release_label() { wv_version_gt "$1" "$(wv_channel_release stable)" && print Experimental || print Stable }
wv_channel_name() { print -r -- "${WV_CHANNEL_NAMES[${WV_CHANNELS[(Ie)$(wv_channel)]}]}" }
# True when something (a background, video or feature, by id) is out on this person's channel.
wv_released() {
  [[ -n "${WV_CHANNEL_ONLY[$1]}" ]] && { [[ "$(wv_channel)" == "${WV_CHANNEL_ONLY[$1]}" ]]; return }
  [[ -n "${WV_SINCE[$1]}" ]] || return 0
  ! wv_version_gt "${WV_SINCE[$1]}" "$(wv_channel_release)"
}
# "4.3 (Stable)", and the installed version too when the channel holds this person back.
wv_version_summary() {
  local shown; shown="$(wv_shown_release)"
  print -r -- "$shown ($(wv_channel_name))${${shown:#$WV_RELEASE}:+, $WV_RELEASE installed}"
}

# ---- Seasonal themes and "Surprise me" (4.0) --------------------------------------------------------------
# Today as YYYY-MM-DD (WV_TODAY overrides it, for testing the seasons).
wv_today() { [[ "$WV_TODAY" == <->-<->-<-> ]] && print -r -- "$WV_TODAY" || /bin/date '+%Y-%m-%d' }

# Western (Gregorian) Easter Sunday as MMDD: the Anonymous Gregorian algorithm.
wv_easter() {
  local -i y=$1 a b c d e g h i k l m month day
  (( a = y % 19, b = y / 100, c = y % 100, d = b / 4, e = b % 4, g = (8 * b + 13) / 25 ))
  (( h = (19 * a + b - d - g + 15) % 30, i = c / 4, k = c % 4 ))
  (( l = (32 + 2 * e + 2 * i - h - k) % 7, m = (a + 11 * h + 19 * l) / 433 ))
  (( month = (h + l - 7 * m + 90) / 25, day = (h + l - 7 * m + 33 * month + 19) % 32 ))
  printf '%02d%02d\n' $month $day
}

# Day of the year (1-366) for <year> <month> <day>.
wv_day_of_year() {
  local -i y=$1 m=$2 d=$3 n=$3 leap=0
  local -a before=(0 31 59 90 120 151 181 212 243 273 304 334)
  (( (y % 4 == 0 && y % 100 != 0) || y % 400 == 0 )) && leap=1
  (( n += before[m] + (m > 2 ? leap : 0) ))
  print $n
}

# The seasonal theme in effect (prints nothing outside the seasons): Fall Sep 22 - Nov 30, Christmas
# Dec 1 - Jan 6, Easter from two weeks before Easter Sunday to Easter Monday.
wv_season() {
  local t="${1:-$(wv_today)}"
  local -i y=$(( 10#${t[1,4]} )) mo=$(( 10#${t[6,7]} )) dd=$(( 10#${t[9,10]} ))
  local -i md=$(( mo * 100 + dd ))
  if (( md >= 922 && md <= 1130 )); then print fall; return; fi
  if (( md >= 1201 || md <= 106 )); then print christmas; return; fi
  local e; e="$(wv_easter $y)"
  local -i dn en
  dn=$(wv_day_of_year $y $mo $dd)
  en=$(wv_day_of_year $y $(( 10#${e[1,2]} )) $(( 10#${e[3,4]} )))
  (( dn >= en - 14 && dn <= en + 1 )) && print easter
  return 0
}

wv_season_index() { print ${WV_SEASONAL[(Ie)$1]} }

# True for someone who hasn't picked a background themselves (or can't: the organization decides).
wv_on_default_background() {
  wv_users_can_change || return 0
  local v; v="$(wv_get Background)"
  ! { wv_valid Background "$v" && wv_released "$v" }
}

# "Surprise me": a different background each day (never the same two days running), the same all day.
wv_surprise_background() {
  local day; day="$(wv_today)"
  local last; last="$(wv_get StateSurpriseBackground)"
  if [[ "$(wv_get StateSurpriseDay)" == "$day" ]] && (( ${WV_BACKGROUNDS[(Ie)$last]} )); then print -r -- "$last"; return; fi
  local -a choices=() b
  for b in ${WV_BACKGROUNDS:#$last}; do wv_released "$b" && choices+=("$b"); done
  local pick="${choices[$(( RANDOM % ${#choices} + 1 ))]}"
  wv_set StateSurpriseDay "$day"; wv_set StateSurpriseBackground "$pick"
  print -r -- "$pick"
}

# A background picked "just for today" or "for one week" (4.2), while that lasts (nothing otherwise).
wv_temp_background() {
  wv_users_can_change || return 0
  local bg until; bg="$(wv_get TempBackground)"; until="$(wv_get TempUntil)"
  wv_valid TempBackground "$bg" && wv_valid TempUntil "$until" && wv_released "$bg" || return 0
  [[ "$until" < "$(wv_today)" ]] && return 0
  print -r -- "$bg"
}

# The background to show today: one picked for a while (4.2), the seasonal theme for people on the default,
# a daily pick for "Surprise me", otherwise the one chosen.
wv_current_background() {
  local t; t="$(wv_temp_background)"
  [[ -n "$t" ]] && { print -r -- "$t"; return; }
  local s; s="$(wv_season)"
  if [[ -n "$s" ]] && wv_on_default_background && [[ -f "$(wv_background_path "$s")" ]]; then print -r -- "$s"; return; fi
  local bg; bg="$(wv_setting Background)"
  [[ "$bg" == surprise ]] && { wv_surprise_background; return; }
  print -r -- "$bg"
}

# The lock screen's background (4.2): the desktop's, unless they picked another one for it.
wv_lock_background() {
  local l; l="$(wv_setting LockBackground)"
  if [[ -n "$l" && "$l" != same ]]; then print -r -- "$l"; else wv_current_background; fi
}

# What "Match my desktop background" plays: the background's own video. A seasonal theme plays its own
# (4.1), or the default background's until that's downloaded.
wv_match_video_id() {
  local id; id="$(wv_current_background)"
  (( ${WV_SEASONAL[(Ie)$id]} )) && [[ ! -f "$WV_DIR/Videos/$id.mp4" ]] && id="$(wv_org Background)"
  print -r -- "$id"
}

# The video file for this person. "match" follows their desktop background (a seasonal theme has no video:
# the default background's plays). "surprise": with "pick" (it's about to play), a different one from last
# time; otherwise the last one picked.
wv_video_file() {   # wv_video_file [pick]
  local id; id="$(wv_setting Video)"
  if [[ "$id" == surprise ]]; then
    local last; last="$(wv_get StateSurpriseVideo)"
    if [[ "$1" == pick ]]; then
      local -a have=() choices=()
      local v; for v in $WV_VIDEOS; do [[ "$v" != (match|surprise) && -f "$WV_DIR/Videos/$v.mp4" ]] && wv_released "$v" && have+=("$v"); done
      choices=(${have:#$last}); (( ${#choices} )) || choices=($have)
      if (( ${#choices} )); then id="${choices[$(( RANDOM % ${#choices} + 1 ))]}"; else id=tla; fi
      wv_set StateSurpriseVideo "$id"
    else
      id="${last:-tla}"
    fi
  elif [[ "$id" == match ]]; then
    id="$(wv_match_video_id)"
  fi
  if [[ -f "$WV_DIR/Videos/$id.mp4" ]]; then wv_video_path "$id"
  else wv_video_path tla; fi
}
# A video's file in this person's light or dark mode (5.0; 5.1: also for the play buttons and the unboxing):
# the dark version where there is one and it's downloaded (Blocks, Frutiger Aero, Liquid Glass and Microsoft so
# far), otherwise the usual one.
wv_video_path() {   # wv_video_path <video id>   (5.1: also Bricks' dark and Penguins' light)
  local mode; mode="$(wv_mode)"
  # (5.4: and out on their channel: Anime's dark one starts on Experimental)
  if [[ -n "$mode" && "${WV_VARIANTS[$1]}" == "$mode" && -f "$WV_DIR/Videos/$1-$mode.mp4" ]] && wv_released "$1-$mode"; then
    print -r -- "$WV_DIR/Videos/$1-$mode.mp4"
  else
    print -r -- "$WV_DIR/Videos/$1.mp4"
  fi
}

# ---- Quiet hours, the greeting and the helpdesk email (4.0) -----------------------------------------------
# True during the quiet hours (on the days) the person set.
wv_quiet_now() {
  [[ "$(wv_setting QuietMode)" == Hours ]] || return 1
  local start end days; start="$(wv_setting QuietStart)"; end="$(wv_setting QuietEnd)"; days=",$(wv_setting QuietDays),"
  local -i s=$(( 10#${start[1,2]} * 60 + 10#${start[4,5]} )) e=$(( 10#${end[1,2]} * 60 + 10#${end[4,5]} ))
  local now; now="${WV_NOW:-$(/bin/date '+%H:%M %u')}"            # e.g. "09:05 1" (1 = Monday)
  local -i m=$(( 10#${now[1,2]} * 60 + 10#${now[4,5]} )) wd=${now[7]}
  local today="${WV_DAYS[wd]}" yesterday="${WV_DAYS[$(( (wd + 5) % 7 + 1 ))]}"
  if (( s <= e )); then [[ "$days" == *",$today,"* ]] && (( m >= s && m < e )); return; fi
  # Overnight (e.g. 21:00 - 07:00): the evening part counts for that day, the morning part for the day before.
  if (( m >= s )); then [[ "$days" == *",$today,"* ]]; return; fi
  (( m < e )) && [[ "$days" == *",$yesterday,"* ]]
}

# Spaces at the start and end removed, runs of spaces made single (4.0.5: the 4.0 version didn't trim).
wv_trim() { local -a w; w=(${=1}); print -r -- "${(j: :)w}" }

# 'Good morning, Audrey!' over the start of the video, when the person has given their name (5.5.5: and hasn't
# turned the greeting off; their name stays either way).
wv_greeting() {
  wv_released greeting-switch && [[ "$(wv_setting Greeting)" == 0 ]] && return 0
  local name; name="$(wv_trim "$(wv_setting PreferredName)")"
  [[ -n "$name" ]] || return 0
  local -i h=$(( 10#${${WV_NOW:-$(/bin/date '+%H')}[1,2]} ))
  local part=evening; (( h < 17 )) && part=afternoon; (( h < 12 )) && part=morning
  print -r -- "Good $part, $name!"
}

# 5.5.5: each theme's intro video greets in its own style (tla-player draws it; see the keys in player.c). The same
# table is in the Windows (play-video.ps1) and Linux (greeting.lua) players. A video without one: the classic fade.
typeset -gA WV_GREETING_STYLES=(
  tla           'a=line;t0=0.3;d=0.5;e=lin'
  microsoft     'a=line;d=0.8;e=out;dy=-0.5;w=semibold'
  liquid-glass  'a=line;d=0.9;e=back;sc=0.85;p=glass;w=semibold'
  penguins      'a=seq;st=0.035;d=0.7;e=back;dx=-2.5;sh=0B2545B3:0.12:0:-0.04'
  code          'a=seq;t0=0.4;st=0.06;d=0;e=step;f=mono;c=4AF626;gl=4AF62699:0.12;p=term;pre=> ;cur=_'
  frutiger-aero 'a=line;d=0.9;e=elastic;sc=0.4;f=round;gl=4FD8FF:0.25'
  solarpunk     'a=seq;st=0.045;d=0.6;e=back;sy=0;an=b;c=FFFBEA;gl=7BD389:0.22'
  rainy         'a=seq;st=0.05;d=0.65;e=bounce;dy=2.2;c=DCEBFF;sh=0A1A33B3:0.1:0:-0.04'
  space         'a=rand;st=0.05;d=1.0;e=out;sc=2.2;ls=0.1;gl=B28DFF:0.3'
  ocean         'a=seq;st=0.05;d=1.1;e=out;dy=-1.6;bob=0.06;bp=2.4;c=B8F3FF;gl=0096C8:0.22'
  beach         'a=seq;st=0.05;d=0.7;e=out;dy=-0.6;bob=0.09;bp=1.8;c=FFF1C9;sh=B4462899:0.12:0:-0.04'
  claymation    'a=seq;st=0.065;d=0.7;e=elastic;sx=1.5;sy=0.3;an=b;f=round;w=heavy;c=FFB347;sh=5A2D0C:0:0.05:-0.06'
  blocks        'a=seq;st=0.07;d=0.7;e=bounce;dy=3;w=heavy;c=FF5A5A,FFD93D,5BD66B,4DA6FF;sh=000000B3:0:0.05:-0.05'
  bricks        'a=seq;st=0.075;d=0.35;e=out;sc=2.2;an=b;w=heavy;sh=B23A1E:0:0.06:-0.06'
  pixel         'a=seq;st=0.06;d=0;e=step;f=mono;c=FFD93D;sh=000000:0:0.07:-0.07;x=step'
  anime         'a=line;t0=0.25;d=0.45;e=back;sc=2.6;r=-6;it=1;w=heavy;gl=FF5FA2:0.12'
  sky-city      'a=line;d=1.6;e=out;dy=1.2;bob=0.05;bp=3.2;gl=7EC8FFCC:0.25'
)
# The style for a video file (Videos/<id>[-dark|-light].mp4; the other versions of a video share its style).
wv_greeting_style() {   # wv_greeting_style <video file>
  wv_released greeting-styles || return 0
  local id="${${1:t}%.mp4}"
  id="${id%-(dark|light)}"; id="${id%-(v2|original)}"
  print -r -- "${WV_GREETING_STYLES[$id]}"
}

wv_urlencode() {
  local LC_ALL=C s="$1" out="" c i
  for (( i = 1; i <= ${#s}; i++ )); do
    c="${s[i]}"
    if [[ "$c" == [A-Za-z0-9._~-] ]]; then out+="$c"; else out+="$(printf '%%%02X' "'$c")"; fi
  done
  print -r -- "$out"
}

# The helpdesk email, with this Mac's details filled in, so reports say where they're from.
wv_helpdesk_link() {
  local bg; bg="$(wv_current_background)"
  local name; name="${WV_BACKGROUND_NAMES[${WV_BACKGROUNDS[(Ie)$bg]}]}"
  (( ${WV_SEASONAL[(Ie)$bg]} )) && name="${WV_SEASONAL_NAMES[${WV_SEASONAL[(Ie)$bg]}]}"
  local video; video="${WV_VIDEO_NAMES[${WV_VIDEOS[(Ie)$(wv_setting Video)]}]}"
  local body=$'\n\n\n-- Please keep these details: they help the helpdesk --\n'
  body+="Computer: $(/usr/sbin/scutil --get ComputerName 2>/dev/null)"$'\n'
  body+="System: macOS $(/usr/bin/sw_vers -productVersion) ($(/usr/bin/sw_vers -buildVersion))"$'\n'
  body+="TLA BootPaper: $(wv_version_summary)"$'\n'"Background: ${name:-$bg}"$'\n'"Intro video: $video"$'\n'
  print -r -- "mailto:$WV_HELPDESK?subject=$(wv_urlencode 'TLA BootPaper (Mac)')&body=$(wv_urlencode "$body")"
}

# "Report a problem" (4.3): what the helpdesk needs to find this Mac and see what state it's in, one
# "Label: value" line each. Anything that can't be read is left out.
wv_device_details() {
  local hw pw line v
  print -r -- "Computer: $(/usr/sbin/scutil --get ComputerName 2>/dev/null)"
  hw="$(/usr/sbin/system_profiler SPHardwareDataType 2>/dev/null)"
  for line in "${(@f)hw}"; do
    line="${line#"${line%%[![:space:]]*}"}"
    case "$line" in
      "Model Name: "*)       v="${line#*: }" ;;
      "Model Identifier: "*) [[ -n "$v" ]] && print -r -- "Model: $v (${line#*: })"; v="" ;;
      "Chip: "*|"Processor Name: "*) print -r -- "Processor: ${line#*: }" ;;
      "Memory: "*)           print -r -- "Memory: ${line#*: }" ;;
      "Serial Number (system): "*) print -r -- "Serial number: ${line#*: }" ;;
    esac
  done
  print -r -- "System: macOS $(/usr/bin/sw_vers -productVersion) ($(/usr/bin/sw_vers -buildVersion))"
  local boot; boot="$(/usr/sbin/sysctl -n kern.boottime 2>/dev/null)"; boot="${${boot#*sec = }%%,*}"
  if [[ "$boot" == <-> ]]; then
    local -i ago=$(( $(/bin/date +%s) - boot )) n
    local when
    if (( ago < 7200 )); then n=$(( ago / 60 )); when="$n minutes ago"
    elif (( ago < 172800 )); then n=$(( ago / 3600 )); when="$n hours ago"
    else n=$(( ago / 86400 )); when="$n days ago"; fi
    print -r -- "Last restart: $(wv_trim "$(/bin/date -r "$boot" '+%a %b %e, %l:%M %p')") ($when)"
  fi
  local df; df="$(/bin/df -k /System/Volumes/Data 2>/dev/null | /usr/bin/awk 'NR == 2 { printf "%.0f GB free of %.0f GB", $4 / 1000000, $2 / 1000000 }')"
  [[ -n "$df" ]] && print -r -- "Storage: $df"
  local batt; batt="$(/usr/bin/pmset -g batt 2>/dev/null)"
  if [[ "$batt" == *InternalBattery* ]]; then
    local pct state=on\ battery
    pct="${${batt##*InternalBattery-0*	}%%%*}"; pct="${pct##*[^0-9]}"
    [[ "$batt" == *"'AC Power'"* ]] && state="plugged in"
    pw="$(/usr/sbin/system_profiler SPPowerDataType 2>/dev/null)"
    local cond="" maxc=""
    for line in "${(@f)pw}"; do
      line="${line#"${line%%[![:space:]]*}"}"
      [[ "$line" == "Condition: "* ]] && cond="${line#*: }"
      [[ "$line" == "Maximum Capacity: "* ]] && maxc="${line#*: }"
    done
    print -r -- "Battery: ${pct:+$pct%, }$state${maxc:+; health $maxc of new}${cond:+ ($cond)}"
  fi
  local dev; dev="$(/usr/sbin/networksetup -listallhardwareports 2>/dev/null | /usr/bin/awk '/Wi-Fi|AirPort/ { getline; print $2; exit }')"
  if [[ -n "$dev" ]]; then
    if [[ -n "$(/usr/sbin/ipconfig getifaddr "$dev" 2>/dev/null)" ]]; then print "Wi-Fi: connected"; else print "Wi-Fi: not connected"; fi
  fi
  print -r -- "TLA BootPaper: $(wv_version_summary)"
  local bg; bg="$(wv_current_background)"
  local name; name="${WV_BACKGROUND_NAMES[${WV_BACKGROUNDS[(Ie)$bg]}]}"
  (( ${WV_SEASONAL[(Ie)$bg]} )) && name="${WV_SEASONAL_NAMES[${WV_SEASONAL[(Ie)$bg]}]}"
  print -r -- "Background: ${name:-$bg}"
  print -r -- "Intro video: ${WV_VIDEO_NAMES[${WV_VIDEOS[(Ie)$(wv_setting Video)]}]}"
  print -r -- "Reported: $(wv_trim "$(/bin/date '+%A, %B %e, %Y %l:%M %p')")"
}

# Once (4.0): ask what name to greet them by. They can skip it ("Not now"), and change it later in the app.
# 4.0.5: in swiftDialog's window, kept in front of other windows (macOS's own dialog could end up hidden behind
# them and close itself after a while). Only "Save" or "Not now" count as answered: if the window goes away
# any other way, it's asked again at the next login (at most 3 times).
wv_ask_name() {
  local -i tries=$(( ${$(wv_get StateNameTries):-0} + 1 ))
  wv_set StateNameTries "$tries"
  (( tries >= 3 )) && wv_set StateNameAsked 1
  local current; current="$(wv_setting PreferredName)"
  local answer="" rc=1
  if [[ -x "$WV_DIALOG" ]]; then
    local out
    out="$("$WV_DIALOG" --title "What should we call you?" --icon "$WV_ICON" \
      --message "Your intro video will greet you by this name, like **“Good morning, Sam!”** You can change it any time in TLA BootPaper." \
      --textfield "Your name,name=pname,value=$current" \
      --button1text "Save" --button2text "Not now" --ontop --moveable --json --width 560 --height 300 2>/dev/null)"
    rc=$?
    if (( rc == 0 )); then
      answer="name:$(print -r -- "$out" | /usr/bin/plutil -extract pname raw -o - - 2>/dev/null)"
    elif (( rc == 2 )); then
      answer="skip"
    fi
  else
    local icon="$WV_APP/Contents/Resources/AppIcon.icns"
    answer="$(/usr/bin/osascript - "$current" "$icon" 2>/dev/null <<'EOF'
on run argv
  set theIcon to note
  try
    set theIcon to POSIX file (item 2 of argv) as alias
  end try
  activate
  try
    set r to display dialog "Your intro video will greet you by this name, like “Good morning, Sam!” You can change it any time in TLA BootPaper." & return & return & "What should we call you?" default answer (item 1 of argv) buttons {"Not now", "Save"} default button "Save" cancel button "Not now" with title "TLA BootPaper" with icon theIcon giving up after 900
    if gave up of r then return ""
    return "name:" & text returned of r
  on error number n
    if n is -128 then return "skip"
    return ""
  end try
end run
EOF
)"
  fi
  case "$answer" in
    skip) wv_set StateNameAsked 1; wv_log "Greeting name: not now." ;;
    name:*)
      wv_set StateNameAsked 1
      answer="$(wv_trim "${answer#name:}")"; answer="$(wv_trim "${answer[1,$WV_NAME_MAX]}")"
      wv_valid PreferredName "$answer" && wv_save PreferredName "$answer"
      wv_log "Greeting name ${answer:+set}${answer:-left empty}." ;;
    *) wv_log "Greeting name: the question closed without an answer (try $tries of 3)." ;;
  esac
  return 0
}

# The organization's announcement (Intune shows it on the lock screen with the login window message): shown
# in the app too.
# 5.0: Macs that Intune doesn't manage get it from GitHub instead (update.zsh: announcement.txt).
wv_announcement() {
  local v f
  for f in "/Library/Managed Preferences/com.apple.loginwindow" "$WV_DIR/announcement.txt" "/Library/Preferences/com.apple.loginwindow"; do
    if [[ "$f" == *.txt ]]; then
      [[ -s "$f" ]] && v="$(<"$f")" && [[ -n "$v" ]] && { print -r -- "${v//$'\n'/ }"; return; }
    else
      v="$(/usr/bin/defaults read "$f" LoginwindowText 2>/dev/null)" && [[ -n "$v" ]] && { print -r -- "${v//$'\n'/ }"; return; }
    fi
  done
}

wv_video_key() { /usr/bin/stat -f '%z-%m' "$(wv_video_file)" 2>/dev/null }

# ---- Desktop backgrounds -------------------------------------------------------------------------
# "-r2": the 3.2.3 pictures, with extra room above and below so they fill any screen shape without cropping
# the sides. A new file name makes macOS pick up the new picture. "-r5" (3.3.6): the new 16:9 Anime picture.
# 5.0: wv_background_path <id> [light|dark] gives that mode's own picture, where the background has one.
wv_background_path() {
  if [[ -n "$2" && "${WV_VARIANTS[$1]}" == "$2" && -f "$WV_DIR/Backgrounds/$1-$2.jpg" ]]; then
    print -r -- "$WV_DIR/Backgrounds/$1-$2.jpg"; return
  fi
  local r=r2; [[ "$1" == anime ]] && r=r5; print -r -- "$WV_DIR/Backgrounds/$1-$r.jpg"
}
# The picture this person sees for a background, in their light or dark mode (5.0).
wv_shown_path() { wv_background_path "$1" "$(wv_mode)" }
wv_thumb_path() {   # wv_thumb_path <id> [light|dark]
  if [[ -n "$2" && "${WV_VARIANTS[$1]}" == "$2" && -f "$WV_DIR/Backgrounds/thumbs/$1-$2.jpg" ]]; then
    print -r -- "$WV_DIR/Backgrounds/thumbs/$1-$2.jpg"; return
  fi
  if [[ -f "$WV_DIR/Backgrounds/thumbs/$1.jpg" ]]; then print -r -- "$WV_DIR/Backgrounds/thumbs/$1.jpg"
  else wv_background_path "$1" "$2"; fi
}

# ---- Light and dark (5.0) ---------------------------------------------------------------------------
# macOS's own appearance (System Settings > Appearance). Light or Dark: AppleInterfaceStyle says ("Dark" while it's
# dark). Auto: macOS 27 doesn't always record which it is right now, so the system is asked (set-wallpaper.js mode).
# WV_APPEARANCE (Light or Dark) overrides it, for testing. wv_cache_mode keeps the answer for the rest of a script,
# so it's asked once per run.
wv_system_mode() {
  local v
  if [[ -n "$WV_APPEARANCE" ]]; then v="$WV_APPEARANCE"
  elif [[ -n "$WV_SYSTEM_MODE" ]]; then v="$WV_SYSTEM_MODE"
  elif [[ "$(/usr/bin/defaults read -g AppleInterfaceStyleSwitchesAutomatically 2>/dev/null)" == (1|true) ]]; then
    v="$(wv_wallpaper mode)"
    [[ "$v" == (dark|light) ]] || v="$(/usr/bin/defaults read -g AppleInterfaceStyle 2>/dev/null)"
  else
    v="$(/usr/bin/defaults read -g AppleInterfaceStyle 2>/dev/null)"
  fi
  [[ "$v" == [Dd]ark ]] && print dark || print light
}
wv_cache_mode() { typeset -g WV_SYSTEM_MODE; WV_SYSTEM_MODE="$(wv_system_mode)" }
# 'light' or 'dark': what this person's backgrounds show now ('' before the feature is out on their channel: the
# original pictures).
wv_mode() {
  wv_released lightdark || { print -r -- ""; return 0; }
  case "$(wv_setting LightDark)" in
    Light) print light ;;
    Dark)  print dark ;;
    *)     wv_system_mode ;;
  esac
}

# True when a configuration profile (not this app) sets the desktop picture, or turns off changing it
# ("Allow Wallpaper Modification" off blocks apps too, not just System Settings).
wv_background_locked() {
  local f me; me="$(/usr/bin/id -un)"
  for f in "/Library/Managed Preferences/com.apple.desktop.plist" \
           "/Library/Managed Preferences/$me/com.apple.desktop.plist"; do
    [[ -f "$f" ]] && /usr/bin/defaults read "${f%.plist}" override-picture-path >/dev/null 2>&1 && return 0
  done
  for f in "/Library/Managed Preferences/com.apple.applicationaccess.plist" \
           "/Library/Managed Preferences/$me/com.apple.applicationaccess.plist"; do
    [[ -f "$f" && "$(/usr/bin/defaults read "${f%.plist}" allowWallpaperModification 2>/dev/null)" == (0|false) ]] && return 0
  done
  return 1
}

wv_wallpaper() { /usr/bin/osascript -l JavaScript "$WV_DIR/set-wallpaper.js" "$@" 2>/dev/null }

# True when any screen isn't showing this person's chosen preset (a new choice, a new default, or they
# changed it some other way). The login script then puts the preset back.
wv_background_needed() {
  wv_background_locked && return 1
  local want; want="$(wv_shown_path "$(wv_current_background)")"   # (5.0: in their light or dark mode)
  [[ -f "$want" ]] || return 1
  # (4.2: and fitted the way they chose)
  [[ "$(wv_get StateAppliedFit)" == "$(wv_setting WallpaperFit)" ]] || return 0
  local line now; now="$(wv_wallpaper get)"
  for line in "${(@f)now}"; do
    [[ "$line" == "$want" ]] || { wv_apply_backoff "$want" "$now" && return 1; return 0; }
  done
  return 1
}

# 5.0: no retrying over and over when macOS won't show the picture (a full-screen app, for example: macOS sets the
# picture for the Space that's showing, and a full-screen app's Space reads back something else). After a try that
# didn't take, the same situation (the picture wanted, what the screens show, the app in front) waits 10 minutes;
# anything changing (they leave full screen, switch apps) tries again straight away.
wv_apply_signature() {   # wv_apply_signature <file wanted> <what the screens show>
  # (lsappinfo front: "... ASN:0x0-0x30030: (in front)"; info -only bundleid: a line like bundleID="com.apple.Safari")
  local asn front MATCH; asn="$(/usr/bin/lsappinfo front 2>/dev/null)"
  [[ "$asn" =~ 'ASN:0x[0-9a-fA-F]+-0x[0-9a-fA-F]+' ]] && asn="$MATCH"
  front="$(/usr/bin/lsappinfo info -only bundleid "$asn" 2>/dev/null | /usr/bin/awk -F'"' 'tolower($0) ~ /bundle ?id|cfbundleidentifier/ && NF >= 3 { print $(NF-1); exit }')"
  print -r -- "$1|${2//$'\n'/,}|$front"
}
wv_apply_backoff() {     # true while the last failed try had this same situation, less than 10 minutes ago
  local at; at="$(wv_get StateApplyFailAt)"
  [[ "$at" == <-> ]] && (( $(/bin/date +%s) - at < 600 )) || return 1
  [[ "$(wv_get StateApplyFailSig)" == "$(wv_apply_signature "$1" "$2")" ]]
}

wv_apply_background() {
  if wv_background_locked; then wv_log "A configuration profile locks the desktop picture; not changing it."; return 1; fi
  # The background to show today (4.0: the seasonal theme or today's "Surprise me" pick, when that applies).
  local id="$1"
  [[ -z "$id" || "$id" == surprise ]] || (( ${WV_SEASONAL[(Ie)$id]} )) && id="$(wv_current_background)"
  local mode; mode="$(wv_mode)"
  local file; file="$(wv_background_path "$id" "$mode")"   # (not "path": in zsh that's tied to $PATH; 5.0: light or dark)
  [[ -f "$file" ]] || { wv_log "Background file missing: $file"; return 1; }
  # 4.0.5: check that every screen really shows it afterwards, and try again if one doesn't (macOS sometimes
  # accepts the picture without showing it, for example while the desktop is still loading).
  local fit; fit="$(wv_setting WallpaperFit)"    # (4.2: fill the screen, or show the whole picture)
  # 5.0: only the screens that show something else are set (no flicker on the others), unless the fit changed.
  local which=changed; [[ "$(wv_get StateAppliedFit)" == "$fit" ]] || which=all
  local try result="" line ok now
  for try in 1 2 3; do
    result="$(wv_wallpaper set "$file" "$fit" "$which")"
    ok=1; now="$(wv_wallpaper get)"
    for line in "${(@f)now}"; do [[ "$line" == "$file" ]] || ok=0; done
    (( ok )) && break
    sleep 1
  done
  if (( ok )); then
    wv_set StateAppliedBackground "$id${mode:+-$mode}"; wv_set StateAppliedFit "$fit"
    wv_unset StateApplyFailSig; wv_unset StateApplyFailAt
    wv_log "Desktop picture set to $id${mode:+ ($mode)} ($fit)${${try:#1}:+ (try $try)}."
    wv_update_lock_screen "$(wv_shown_path "$(wv_lock_background)")"   # (4.2: its own, if they picked one)
  else
    # (5.0: not again for the same situation for 10 minutes; see wv_apply_backoff)
    wv_set StateApplyFailSig "$(wv_apply_signature "$file" "$now")"; wv_set StateApplyFailAt "$(/bin/date +%s)"
    wv_log "macOS didn't show the desktop picture $id (answer: ${result:-none}; screens: ${(j:, :)${(f)now}}; macOS $(/usr/bin/sw_vers -productVersion)). Trying again in 10 minutes, or sooner if something changes."
    return 1
  fi
}

# The picture macOS shows at the login window and lock screen is its own saved copy of the desktop picture
# (/Library/Caches/Desktop Pictures/<user's GUID>/lockscreen.png). guard.zsh (as root, every 20 seconds) keeps it in
# step; 4.0.5: also done here straight away when the person can (that folder is theirs once guard.zsh has made it).
wv_update_lock_screen() {   # wv_update_lock_screen <picture>
  local src="$1" guid cache stamp
  guid="$(/usr/bin/dscl . -read "/Users/$(/usr/bin/id -un)" GeneratedUID 2>/dev/null | /usr/bin/awk '{ print $2 }')"
  [[ -n "$guid" ]] || return 0
  cache="/Library/Caches/Desktop Pictures/$guid"
  [[ -d "$cache" && -w "$cache" ]] || return 0
  [[ -f "$src" ]] || return 0
  # (4.2: the copy's own date is part of the record too, so a copy macOS made since is replaced as well)
  stamp="$src $(/usr/bin/stat -f %m "$src")"
  [[ -f "$cache/lockscreen.png" && "$(/bin/cat "$cache/.tla-bootpaper" 2>/dev/null)" == "$stamp|$(/usr/bin/stat -f %m "$cache/lockscreen.png")" ]] && return 0
  if /usr/bin/sips -s format png "$src" --out "$cache/.lockscreen.tmp.png" >/dev/null 2>&1 &&
     /bin/mv -f "$cache/.lockscreen.tmp.png" "$cache/lockscreen.png"; then
    /bin/chmod 644 "$cache/lockscreen.png" 2>/dev/null
    print -r -- "$stamp|$(/usr/bin/stat -f %m "$cache/lockscreen.png")" > "$cache/.tla-bootpaper"
    wv_log "Lock screen picture updated."
  fi
  return 0
}

# Puts the person's background in place after they pick one in the app (settings.zsh --apply, in the
# background). 4.0.5: the newest pick wins. Picking several quickly starts one of these for each; they take
# turns, and any that a newer pick has replaced stop without doing anything.
wv_apply_latest() {
  local ticket="$$-$RANDOM-$(/bin/date +%s)"
  wv_set StateApplyTicket "$ticket"
  zmodload zsh/system 2>/dev/null
  local lockfile="${TMPDIR:-/tmp}/tla-bootpaper-apply-$UID.lock" fd
  : >> "$lockfile" 2>/dev/null
  zsystem flock -t 120 -f fd "$lockfile" 2>/dev/null   # (if it can't lock, it goes ahead anyway)
  [[ "$(wv_get StateApplyTicket)" == "$ticket" ]] || return 0
  # (a pick in the app is a new situation: no waiting from an earlier try that didn't take)
  wv_unset StateApplyFailSig; wv_unset StateApplyFailAt
  wv_background_needed && wv_apply_background
  wv_background_locked || wv_update_lock_screen "$(wv_shown_path "$(wv_lock_background)")"   # (4.2)
  return 0
}

# ---- Video -----------------------------------------------------------------------------------------
wv_play_video() {   # wv_play_video [force|unbox [<video id> [mute]]]   ("force" = the app's Play button: always closable, not recorded)
  local video; video="$(wv_video_file pick)"
  # 4.2: the app can play a given video (the play button on a background's picture), and without sound.
  # 5.0: "unbox" = the first login after preparing the Mac for unboxing (TLA Classic, whatever they'd picked).
  # 5.1: in their light or dark mode, like the video at login.
  [[ "$1" == (force|unbox) && -n "$2" && "$2" != - && -f "$WV_DIR/Videos/$2.mp4" ]] && video="$(wv_video_path "$2")"
  [[ -f "$video" ]] || { wv_log "No intro video yet (they download after the install)."; return 1; }
  local was_muted="" quiet=0
  [[ "$1" == force && "$3" == mute ]] && quiet=1
  # Quiet hours (4.0): no sound during the hours they set.
  [[ "$(wv_setting Sound)" != 0 ]] && wv_quiet_now && quiet=1
  local greeting style=""; greeting="$(wv_greeting)"
  [[ -n "$greeting" ]] && style="$(wv_greeting_style "$video")"   # (5.5.5)
  if [[ "$(wv_setting Sound)" == 0 ]] || (( quiet )); then
    was_muted="$(/usr/bin/osascript -e 'output muted of (get volume settings)' 2>/dev/null)"
    /usr/bin/osascript -e 'set volume with output muted' 2>/dev/null
  fi
  local skip=1
  [[ "$1" != force && "$(wv_setting AllowSkip)" == 0 ]] && skip=0
  wv_log "Playing $(/usr/bin/basename "$video") (${1:-login}, skip $skip${${quiet:#0}:+, quiet hours}${greeting:+, with greeting})."
  if [[ "$1" != force ]]; then   # (alongside the video, so it starts sooner)
    ( wv_set StateLastPlayed "$(/bin/date '+%Y-%m-%d %H:%M')"
      wv_set StateLastPlayedDay "$(/bin/date '+%Y-%m-%d')"
      wv_set StateLastPlayedVideo "$(wv_video_key)" ) &
  fi
  # Full screen on every display, above the menu bar and Dock: the native player (screens black within a
  # fraction of a second), or the JavaScript one built into macOS if that can't run.
  local result=""
  [[ -x "$WV_DIR/tla-player" ]] && result="$("$WV_DIR/tla-player" "$video" "$skip" 180 "$greeting" "$style" 2>/dev/null)"
  [[ "$result" == (played|skipped) ]] || result="$(/usr/bin/osascript -l JavaScript "$WV_DIR/play-video.js" "$video" "$skip" 180 "$greeting" "$style" 2>&1)"
  wv_log "Video: ${result:-no result}"
  if [[ "$result" != (played|skipped) && -x "$WV_DIALOG" ]]; then
    # Fallback: swiftDialog, in a window the size of the screen.
    local size; size="$(/usr/bin/osascript -l JavaScript -e 'ObjC.import("AppKit"); const s = $.NSScreen.mainScreen; Math.round(s.frame.size.width) + " " + Math.round(s.visibleFrame.size.height)' 2>/dev/null)"
    local width="${size%% *}" height="${size##* }"
    [[ "$width" == <-> && "$height" == <-> ]] || { width=1280; height=760; }
    local -a args=(--title none --icon none --video "$video" --autoplay
                   --button1text "Skip" --ontop --blurscreen --position center
                   --width "$width" --height "$height")
    (( skip )) || args+=(--button1disabled)
    (( ${AUTO_CLOSE_SECONDS:-0} > 0 )) && args+=(--timer "$AUTO_CLOSE_SECONDS" --hidetimerbar)
    "$WV_DIALOG" "${args[@]}" >/dev/null 2>&1
  fi
  [[ "$was_muted" == false ]] && /usr/bin/osascript -e 'set volume without output muted' 2>/dev/null
  return 0
}

# ---- Release log -----------------------------------------------------------------------------------
# release-notes.md is shared with Windows: lines tagged [win] are skipped, [mac] tags are removed.
# 4.3: each release is marked (Stable) or (Experimental), and releases newer than this person's channel are left out.
wv_release_markdown() {   # wv_release_markdown [number of versions]   (all of them by default)
  /usr/bin/awk -v max="${1:-0}" -v chan="$(wv_vkey "$(wv_channel_release)")" -v stable="$(wv_vkey "$(wv_channel_release stable)")" '
    function vkey(v,   p, n, i, k) { n = split(v, p, "."); k = ""
                                     for (i = 1; i <= 4; i++) k = k sprintf("%04d", (i <= n ? p[i] + 0 : 0)); return k }
    /^#[ \t]/ { t = $0; sub(/^#[ \t]+/, "", t); skip = 0
                if (t ~ /^\[win\]/) { skip = 1; next }
                sub(/^\[mac\][ \t]*/, "", t)
                if (match(t, /Version [0-9][0-9.]*/)) {
                  v = substr(t, RSTART + 8, RLENGTH - 8); k = vkey(v)
                  if (k > chan) { skip = 1; next }
                  t = t (k > stable ? " (Experimental)" : " (Stable)")
                }
                if (max > 0 && ++shown > max) exit
                print "### " t; next }
    skip { next }
    /^-[ \t]/ { t = $0; sub(/^-[ \t]+/, "", t)
                if (t ~ /^\[win\]/) next
                sub(/^\[mac\][ \t]*/, "", t); print "- " t; next }
    { print }
  ' "$WV_DIR/release-notes.md"
}

wv_show_whats_new() {   # wv_show_whats_new [fromapp]
  [[ -x "$WV_DIALOG" ]] || return 1
  local -a args=(--title "What's new in TLA BootPaper" --icon "$WV_ICON" --message "$(wv_release_markdown 3)"
                 --infotext "You're on version $(wv_shown_release), $(wv_channel_name)" --button1text "Got it" --moveable
                 --width 720 --height 620)
  [[ "$1" != fromapp ]] && args+=(--button2text "Open TLA BootPaper" --ontop)
  [[ "$1" != fromapp ]] && wv_set StateSeenRelease "$(wv_shown_release)"
  "$WV_DIALOG" "${args[@]}" >/dev/null 2>&1
  local rc=$?
  [[ "$1" != fromapp && $rc -eq 2 ]] && /usr/bin/open "$WV_APP"
  return 0
}

# ==== 5.0 ======================================================================================================
# ---- The TLA screensaver: Aerial playing the TLA video ---------------------------------------------------------
# screensaver-setup.zsh (as root) installs Aerial and sets it up; this makes it this person's screensaver.
WV_AERIAL_EXT="com.glouel.Aerial-App.Aerial4WallpaperExtension"
WV_AERIAL_APP="/Applications/Aerial.app"
wv_aerial_idle() { /usr/bin/osascript -l JavaScript "$WV_DIR/aerial-idle.js" "$@" 2>/dev/null }

# True when a configuration profile chooses the screensaver (then it's the organization's choice, not ours).
wv_screensaver_managed() {   # wv_screensaver_managed [idleTime]   (with idleTime: whether it sets the waiting time)
  local f k me; me="$(/usr/bin/id -un)"
  local -a keys=(moduleName modulePath moduleDict); [[ "$1" == idleTime ]] && keys=(idleTime)
  for f in "/Library/Managed Preferences/com.apple.screensaver.plist" "/Library/Managed Preferences/$me/com.apple.screensaver.plist"; do
    [[ -f "$f" ]] || continue
    for k in $keys; do /usr/bin/defaults read "${f%.plist}" "$k" >/dev/null 2>&1 && return 0; done
  done
  return 1
}

# Makes (or stops making) Aerial this person's screensaver. Prints what happened: set | off | theirs | policy |
# needs-macos-26 | unavailable | failed. "force": they just turned it on in the app (so it replaces even a
# screensaver they'd chosen themselves). Like on Windows: someone's own screensaver stays, unless they turn the TLA
# one on in the app; turning it off puts back the one from before.
wv_update_screensaver() {
  wv_screensaver_managed && { print policy; return 0; }
  local want=0; wv_released screensaver && [[ "$(wv_setting Screensaver)" != 0 ]] && want=1
  local explicit=0; [[ "$(wv_get Screensaver)" == 1 ]] && explicit=1
  local setbyus=0; [[ "$(wv_get StateScreensaverSet)" == 1 ]] && setbyus=1
  local current r; current="$(wv_aerial_idle get)"
  if (( ! want )); then
    if (( setbyus )) && [[ "$current" == "$WV_AERIAL_EXT" ]]; then
      r="$(wv_aerial_idle restore)"
      if [[ "$r" == ok ]]; then /usr/bin/killall WallpaperAgent 2>/dev/null; wv_log "TLA screensaver off: the screensaver from before is back."; fi
    fi
    wv_set StateScreensaverSet 0
    print off; return 0
  fi
  if [[ "$current" == "$WV_AERIAL_EXT" ]]; then wv_set StateScreensaverSet 1; print set; return 0; fi
  # They chose another screensaver after TLA BootPaper set this one: theirs stays.
  if (( setbyus && ! explicit )) && [[ "$1" != force ]]; then print theirs; return 0; fi
  local st; st="$(/bin/cat "$WV_DIR/Screensaver/status" 2>/dev/null)"
  [[ "$st" == needs-macos-26 ]] && { print needs-macos-26; return 0; }
  [[ "$st" == ready && -d "$WV_AERIAL_APP" ]] || { print unavailable; return 0; }
  # (at most once a day after a try that didn't work, unless they asked for it in the app)
  [[ "$1" != force && "$(wv_get StateScreensaverFailDay)" == "$(wv_today)" ]] && { print failed; return 0; }
  # macOS needs to know Aerial's screensaver (normally it finds it by itself; this makes sure).
  if ! /usr/bin/pluginkit -m -i "$WV_AERIAL_EXT" 2>/dev/null | /usr/bin/grep -q "$WV_AERIAL_EXT"; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$WV_AERIAL_APP" 2>/dev/null
    /usr/bin/pluginkit -a "$WV_AERIAL_APP/Contents/Extensions/Aerial4WallpaperExtension.appex" 2>/dev/null
  fi
  /usr/bin/pluginkit -e use -i "$WV_AERIAL_EXT" 2>/dev/null
  r="$(wv_aerial_idle set "$WV_AERIAL_EXT" aerial)"
  if [[ "$r" != ok ]]; then
    wv_set StateScreensaverFailDay "$(wv_today)"; wv_log "TLA screensaver: ${r:-no answer}"; print failed; return 0
  fi
  /usr/bin/killall WallpaperAgent 2>/dev/null      # (it reads the change when it starts again)
  local i; for i in 1 2 3 4 5 6; do sleep 1; current="$(wv_aerial_idle get)"; [[ "$current" == "$WV_AERIAL_EXT" ]] && (( i >= 3 )) && break; done
  if [[ "$current" != "$WV_AERIAL_EXT" ]]; then
    wv_set StateScreensaverFailDay "$(wv_today)"; wv_log "TLA screensaver: macOS didn't keep it (screensaver: ${current:-none})."; print failed; return 0
  fi
  wv_set StateScreensaverSet 1; wv_unset StateScreensaverFailDay
  # After 5 minutes without use, unless they (or the organization) chose a time; macOS's own default is 20 minutes.
  local idle; idle="$(/usr/bin/defaults -currentHost read com.apple.screensaver idleTime 2>/dev/null)"
  if ! wv_screensaver_managed idleTime && [[ -z "$idle" || ( "$idle" == <-> && "$idle" -ge 900 ) ]]; then
    /usr/bin/defaults -currentHost write com.apple.screensaver idleTime -int 300
  fi
  wv_log "TLA screensaver set (Aerial, the TLA video)."
  print set
}

# ---- TLA call backgrounds for Microsoft Teams ------------------------------------------------------------------
# The pictures (Calls/<name>.jpg, 1920x1080, and Calls/thumbs/<name>.jpg) go into new Teams' own folder of uploaded
# backgrounds, under fixed names (the same as on Windows), so they're added once and replaced, never doubled. macOS
# asks the person to allow it the first time ("would like to access data from other apps").
WV_TEAMS_UPLOADS="$HOME/Library/Containers/com.microsoft.teams2/Data/Library/Application Support/Microsoft/MSTeams/Backgrounds/Uploads"
wv_teams_installed() {   # (5.1: also under its 2023-24 name, or wherever Spotlight finds it)
  local a; for a in "Microsoft Teams" "Microsoft Teams (work or school)"; do
    [[ -d "/Applications/$a.app" || -d "$HOME/Applications/$a.app" ]] && return 0
  done
  [[ -d "$HOME/Library/Containers/com.microsoft.teams2" ]] && return 0
  [[ -n "$(/usr/bin/mdfind "kMDItemCFBundleIdentifier == 'com.microsoft.teams2'" 2>/dev/null | /usr/bin/head -1)" ]]
}
wv_call_guid() {   # a version 3 (name-based) GUID from the picture's name
  local h; h="$(/sbin/md5 -q -s "TLA BootPaper call background|$1")"
  local -i b6=$(( 16#${h[13,14]} )) b8=$(( 16#${h[17,18]} ))
  h="${h[1,12]}$(printf '%02x' $(( (b6 & 0x0F) | 0x30 )))${h[15,16]}$(printf '%02x' $(( (b8 & 0x3F) | 0x80 )))${h[19,32]}"
  print -r -- "${h[1,8]}-${h[9,12]}-${h[13,16]}-${h[17,20]}-${h[21,32]}"
}
# Every background out on their channel, in both its light and dark picture.
wv_call_pictures() {
  local id
  for id in $WV_BACKGROUNDS; do
    wv_released "$id" || continue
    print -r -- "$id"
    [[ -n "${WV_VARIANTS[$id]}" ]] && wv_released lightdark && print -r -- "$id-${WV_VARIANTS[$id]}"
  done
}
# wv_call_backgrounds add | remove: prints "added <n>" | "removed <n>" | "no-teams" | "denied" | "none".
wv_call_backgrounds() {
  local up="$WV_TEAMS_UPLOADS"
  [[ "$up" == */Backgrounds/Uploads ]] || { print none; return 0; }
  local -a placed=(${(s:;:)$(wv_get StateCallBackgroundFiles)}) keep=()
  local name guid; local -i n=0 gone=0
  if [[ "$1" == add ]]; then
    wv_teams_installed || { print no-teams; return 0; }
    /bin/mkdir -p "$up" 2>/dev/null
    /usr/bin/touch "$up/.tla-bootpaper" 2>/dev/null || { print denied; return 0; }
    /bin/rm -f "$up/.tla-bootpaper"
    for name in $(wv_call_pictures); do
      [[ -f "$WV_DIR/Calls/$name.jpg" && -f "$WV_DIR/Calls/thumbs/$name.jpg" ]] || continue
      guid="$(wv_call_guid "$name")"; [[ "$guid" == ????????-????-????-????-???????????? ]] || continue
      keep+=("$guid")
      if ! /usr/bin/cmp -s "$WV_DIR/Calls/$name.jpg" "$up/$guid.jpg"; then
        /bin/cp -f "$WV_DIR/Calls/$name.jpg" "$up/$guid.jpg" 2>/dev/null &&
          /bin/cp -f "$WV_DIR/Calls/thumbs/$name.jpg" "$up/${guid}_thumb.jpg" 2>/dev/null && (( n++ ))
      fi
    done
  fi
  # Ours that are no longer wanted (taken off, or a background no longer offered).
  for guid in $placed; do
    [[ "$guid" == ????????-????-????-????-???????????? ]] || continue
    (( ${keep[(Ie)$guid]} )) && continue
    /bin/rm -f "$up/$guid.jpg" "$up/${guid}_thumb.jpg" 2>/dev/null && (( gone++ ))
  done
  wv_set StateCallBackgroundFiles "${(j:;:)keep}"
  if [[ "$1" == add ]]; then
    (( ${#keep} )) || { print none; return 0; }
    wv_log "TLA call backgrounds in Teams: ${#keep} ($n new)."; print "added ${#keep}"
  else
    wv_log "TLA call backgrounds taken out of Teams ($gone)."; print "removed $gone"
  fi
}

# ---- Touch ID, teachers and their password (5.1) ---------------------------------------------------------
# Touch ID: none (no sensor, built in or on a Magic Keyboard), set (this person has a fingerprint) or available.
wv_touchid_state() {
  local hw=0
  /usr/sbin/ioreg -r -d 1 -c AppleBiometricSensor 2>/dev/null | /usr/bin/grep -q AppleBiometricSensor && hw=1
  (( hw )) || { /usr/sbin/ioreg -r -d 1 -c AppleMesaSEPDriver 2>/dev/null | /usr/bin/grep -q AppleMesaSEPDriver && hw=1; }
  (( hw )) || { /usr/bin/bioutil -r -s 2>/dev/null | /usr/bin/grep -Eq '[Ff]unctionality: *1' && hw=1; }
  (( hw )) || { print none; return 0; }
  local -i fingers; fingers="$(/usr/bin/bioutil -c 2>/dev/null | /usr/bin/awk '/template/ { for (i = 1; i <= NF; i++) if ($i ~ /^[0-9]+$/) n = $i } END { print n + 0 }')"
  (( fingers > 0 )) && print set || print available
}
# teacher | student | '' (not set): from the Intune "Teacher vs. Student" profile, a preference file for this
# domain with Role = teacher or student (assigned to people or to Macs). Only a profile counts, so nobody can make
# themselves one or the other.
wv_role() {
  local f v
  for f in "/Library/Managed Preferences/$(/usr/bin/id -un)/$WV_DOMAIN.plist" "/Library/Managed Preferences/$WV_DOMAIN.plist"; do
    [[ -f "$f" ]] || continue
    v="$(/usr/bin/plutil -extract Role raw -o - "$f" 2>/dev/null)"
    v="${(L)v}"
    [[ "$v" == (teacher|student) ]] && { print -r -- "$v"; return 0; }
  done
  print -r -- ""
}
# changed | unchanged | unknown: whether this person has changed their password since their account was made
# (macOS keeps both times in accountPolicyData).
wv_password_state() {
  local xml created set
  xml="$(/usr/bin/dscl . -read "/Users/$(/usr/bin/id -un)" accountPolicyData 2>/dev/null | /usr/bin/tail -n +2)"
  [[ -n "$xml" ]] || { print unknown; return 0; }
  created="$(print -r -- "$xml" | /usr/bin/plutil -extract creationTime raw -o - - 2>/dev/null)"
  set="$(print -r -- "$xml" | /usr/bin/plutil -extract passwordLastSetTime raw -o - - 2>/dev/null)"
  created="${created%%.*}"; set="${set%%.*}"
  [[ "$created" == <-> && "$set" == <-> ]] || { print unknown; return 0; }
  (( set > created + 600 )) && print changed || print unchanged    # (the first password is set as the account is made)
}

# ---- Connect to TLA (5.2.5) --------------------------------------------------------------------------------
# A Mac Intune doesn't manage misses what TLA sends through it (the TLA new tab page in Chrome and Edge, apps,
# updates and settings: browsers only take a new tab page from a managed Mac). TLA BootPaper offers to connect it:
# Company Portal enrolls it with the person's TLA account. update.zsh (as root, every 15 minutes) notes in
# Care/mdm whether it's managed, since only root can ask.
WV_COMPANY_PORTAL="/Applications/Company Portal.app"
WV_COMPANY_PORTAL_URL="https://go.microsoft.com/fwlink/?linkid=853070"   # (Microsoft's Company Portal for macOS)
wv_connect_state() {   # connected | not-connected | unknown
  case "$(/bin/cat "$WV_DIR/Care/mdm" 2>/dev/null)" in
    enrolled=yes) print connected ;;
    enrolled=no)  print not-connected ;;
    *)            print unknown ;;
  esac
}
wv_connect_needed() { wv_released connect && [[ "$(wv_connect_state)" == not-connected ]] }
wv_open_connect() {   # Company Portal if it's here, otherwise its download
  if [[ -d "$WV_COMPANY_PORTAL" ]]; then /usr/bin/open -a "$WV_COMPANY_PORTAL"; else /usr/bin/open "$WV_COMPANY_PORTAL_URL"; fi
}

# ---- TLA Care --------------------------------------------------------------------------------------------------
# Checks what most often goes wrong on a school Mac, and fixes what it can. What needs root (the sound system,
# clearing out system leftovers, downloading the videos now, preparing for unboxing) is asked of guard.zsh, which
# runs as root every 20 seconds: the person's "CareRequest" setting holds one word from a fixed list (so nothing
# else can be asked for), and the answer comes back in Care/result ("<word>|<time asked>|<text>").
WV_CARE_REQUESTS=(cleanup audio videos unbox)
wv_care_ago() {   # wv_care_ago <seconds>
  local -i s=$1 h
  if (( s < 120 )); then print "just now"
  elif (( s < 3600 )); then print "$(( s / 60 )) minutes ago"
  elif (( s < 86400 )); then h=$(( s / 3600 )); print "$h hour${${h:#1}:+s} ago"
  elif (( s < 172800 )); then print yesterday
  else print "$(( s / 86400 )) days ago"; fi
}
wv_care_row() { print -r -- "$1	$2	$3	$4	${5:-}	${6:-}" }   # id status title detail [action actiontext]
wv_care_checks() {   # wv_care_checks [quick]   ("quick": only what's worth a reminder, no network test)
  local -i now=$(/bin/date +%s)
  # Restart
  local boot; boot="$(/usr/sbin/sysctl -n kern.boottime 2>/dev/null)"; boot="${${boot#*sec = }%%,*}"
  if [[ "$boot" == <-> ]]; then
    local -i days=$(( (now - boot) / 86400 ))
    if (( days >= 14 )); then wv_care_row restart bad "Restart your Mac" "It hasn't restarted in $days days. A restart keeps it fast and finishes updates." restart "Restart now"
    elif (( days >= 7 )); then wv_care_row restart warn "Time for a restart" "It's been running for $days days. A restart keeps it fast." restart "Restart now"
    else wv_care_row restart ok "Restart" "Restarted $(wv_care_ago $(( now - boot )))."; fi
  fi
  # Storage
  local -a df=(${=$(/bin/df -k /System/Volumes/Data 2>/dev/null | /usr/bin/awk 'NR == 2 { print $2, $4 }')})
  if [[ "${df[1]}" == <-> && "${df[2]}" == <-> ]] && (( df[1] > 0 )); then
    local -F free total pct
    (( free = df[2] / 1000000.0, total = df[1] / 1000000.0, pct = 100.0 * df[2] / df[1] ))
    local text; text="$(printf '%.1f GB free of %.0f GB.' $free $total)"
    if (( pct < 5 || free < 5 )); then wv_care_row storage bad "Almost out of storage" "$text Apps and updates need room to work." cleanup "Free up space"
    elif (( pct < 10 || free < 15 )); then wv_care_row storage warn "Storage is getting full" "$text" cleanup "Free up space"
    else wv_care_row storage ok "Storage" "$text"; fi
  fi
  # Internet
  if [[ "$1" != quick ]]; then
    if /usr/bin/curl -fsS --max-time 4 http://captive.apple.com/hotspot-detect.html 2>/dev/null | /usr/bin/grep -q Success; then
      wv_care_row internet ok "Internet" "Connected."
    else
      wv_care_row internet bad "Can't reach the internet" "Check that Wi-Fi is on and pick your network. If a sign-in page should appear, open Safari." wifi "Wi-Fi settings"
    fi
  fi
  # Sound
  if /usr/bin/pgrep -x coreaudiod >/dev/null 2>&1; then
    wv_care_row sound ok "Sound" "Working. No sound or no microphone? Reset it." audio "Reset sound"
  else
    wv_care_row sound bad "Sound isn't working" "The Mac's sound system has stopped." audio "Fix sound"
  fi
  # Battery (MacBooks)
  local batt; batt="$(/usr/bin/pmset -g batt 2>/dev/null)"
  if [[ "$batt" == *InternalBattery* && "$1" != quick ]]; then
    local charge cond="" maxc="" line
    charge="${${batt##*InternalBattery-0*	}%%%*}"; charge="${charge##*[^0-9]}"
    for line in "${(@f)$(/usr/sbin/system_profiler SPPowerDataType 2>/dev/null)}"; do
      line="${line#"${line%%[![:space:]]*}"}"
      [[ "$line" == "Condition: "* ]] && cond="${line#*: }"
      [[ "$line" == "Maximum Capacity: "* ]] && maxc="${line#*: }"
    done
    if [[ "$cond" == *Service* ]] || { [[ "${maxc%\%}" == <-> ]] && (( ${maxc%\%} < 70 )); }; then
      wv_care_row battery warn "The battery is wearing out" "It holds about ${maxc:-less} of its charge when new${cond:+ (macOS says: $cond)}. If it doesn't last the school day, tell the helpdesk." report "Report it"
    else
      wv_care_row battery ok "Battery" "${charge:+$charge% charged}${maxc:+; battery health $maxc}."
    fi
  fi
  # Connected to TLA (5.2.5: only on Macs Intune doesn't manage)
  if [[ "$1" != quick ]] && wv_connect_needed; then
    wv_care_row connect info "Connect this Mac to TLA" "It's missing what TLA sends, like the TLA new tab page in Chrome and Edge, apps and updates. Sign in with your TLA account in Company Portal." connect "Connect"
  fi
  # Their password (5.1: teachers, until they've changed the one the Mac came with)
  if [[ "$1" != quick && "$(wv_role)" == teacher && "$(wv_password_state)" == unchanged ]]; then
    wv_care_row password warn "Change your password" "TLA teachers are required to change the password their Mac came with to a secure one that only they know." password "Change it"
  fi
  # Touch ID
  if [[ "$1" != quick ]]; then   # (5.1: only on Macs that have Touch ID)
    case "$(wv_touchid_state)" in
      set)       wv_care_row touchid ok "Touch ID" "You're set up: unlock with your fingerprint." ;;
      available) wv_care_row touchid info "Unlock with your fingerprint" "This Mac has Touch ID. It's faster than typing your password." touchid "Set it up" ;;
    esac
  fi
  # TLA BootPaper
  local -i miss=0; local v
  for v in tla $WV_BACKGROUNDS; do [[ "$v" == tla ]] || wv_has_video "$v" || continue; [[ -f "$WV_DIR/Videos/$v.mp4" ]] || (( miss++ )); done
  if (( miss )); then wv_care_row bootpaper info "TLA BootPaper" "$miss intro video${${miss:#1}:+s} still downloading." videos "Download now"
  else wv_care_row bootpaper ok "TLA BootPaper" "Backgrounds and intro videos are all in place."; fi
}

# Asks guard.zsh (root) to do one thing from the list. Prints the time asked (to match its answer).
wv_care_request() {
  (( ${WV_CARE_REQUESTS[(Ie)$1]} )) || return 1
  local at; at="$(/bin/date +%s)"
  wv_set CareRequestAt "$at"; wv_set CareRequest "$1"
  print -r -- "$at"
}
# The answer to a request (prints its text), once guard.zsh has answered.
wv_care_result() {   # wv_care_result <word> <time asked>
  local r; r="$(/bin/cat "$WV_DIR/Care/result" 2>/dev/null)"
  [[ "$r" == "$1|$2|"* ]] || return 1
  print -r -- "${r#$1|$2|}"
}
# The person's own cached files that haven't been used for two weeks (in ~/Library/Caches): apps make them again
# when they need them. Prints how many bytes were freed. WV_CARE_CACHES points it at another Caches folder (tests).
wv_clear_my_caches() {
  local dir="${WV_CARE_CACHES:-$HOME/Library/Caches}"
  [[ "$dir" == /?*/Caches && -d "$dir" ]] || { print 0; return 0; }
  local -i freed=0 size; local f
  for f in "$dir"/**/*(.Nmw+2aw+2); do
    size=$(/usr/bin/stat -f %z "$f" 2>/dev/null || print 0)
    /bin/rm -f -- "$f" 2>/dev/null && (( freed += size ))
  done
  print $freed
}

# A reminder once a day at most, for what's worth doing something about (a restart that's overdue, storage running
# out, sound not working), never the same one two days running unless it got worse, and not at all if they turned
# reminders off. Prints the row, or nothing.
wv_care_nudge() {
  wv_released care && [[ "$(wv_setting CareReminders)" != 0 ]] || return 1
  local today; today="$(wv_today)"
  [[ "$(wv_get StateCareNudgeDay)" == "$today" ]] && return 1
  local row pick=""; local -a f
  for row in "${(@f)$(wv_care_checks quick)}"; do
    f=("${(@ps:\t:)row}")
    [[ "${f[1]}" == (restart|storage|sound) ]] || continue
    [[ "${f[2]}" == bad ]] && { pick="$row"; break; }
    [[ "${f[2]}" == warn && -z "$pick" ]] && pick="$row"
  done
  [[ -n "$pick" ]] || return 1
  f=("${(@ps:\t:)pick}")
  local yesterday; yesterday="$(/bin/date -j -v-1d -f '%Y-%m-%d' "$today" '+%Y-%m-%d' 2>/dev/null)"
  [[ "$(wv_get StateCareNudgeDay)" == "$yesterday" && "$(wv_get StateCareNudgeFor)" == "${f[1]}|${f[2]}" ]] && return 1
  print -r -- "$pick"
}

# ---- Unboxing ("Prepare for initial unboxing") -----------------------------------------------------------------
# Care/unbox (root's): state=ready (on a Mac TLA BootPaper was first installed on, until someone prepares it) |
# armed (prepared, shutting down) | unboxing (it has started up since) | done. armed_at = when it was prepared.
wv_unbox_value() { /usr/bin/awk -F= -v k="$1" '$1 == k { print substr($0, length(k) + 2); exit }' "$WV_DIR/Care/unbox" 2>/dev/null }
wv_boot_time() { local b; b="$(/usr/sbin/sysctl -n kern.boottime 2>/dev/null)"; b="${${b#*sec = }%%,*}"; [[ "$b" == <-> ]] && print -r -- "$b" }
# True (and prints armed_at) when this login is the unboxing: prepared, started up since, and this person hasn't
# had it yet. (armed_by=update: a Mac that already had TLA BootPaper when 5.0 arrived; it waits until the tour is
# out on this person's release channel.)
wv_unbox_pending() {
  local st at boot; st="$(wv_unbox_value state)"; at="$(wv_unbox_value armed_at)"
  [[ "$st" == (armed|unboxing) && "$at" == <-> ]] || return 1
  [[ "$(wv_get StateUnboxShown)" == "$at" ]] && return 1
  [[ "$(wv_unbox_value armed_by)" == update ]] && ! wv_released tour && return 1
  if [[ "$st" == armed ]]; then
    boot="$(wv_boot_time)"
    [[ -n "$boot" ]] && (( boot > at )) || return 1
  fi
  print -r -- "$at"
}
