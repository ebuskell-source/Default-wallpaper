#!/bin/zsh
# sync-videos.zsh - runs as root. Downloads any intro video that's missing or out of date (approved design,
# 3.2.3): the videos aren't in the package, which keeps it small and the videos at full quality. Each one is
# kept only if its SHA-256 matches the list below, so a changed or damaged file is never used.
# Called by the package's postinstall and by guard.zsh every 15 minutes.
# 4.3: also reads which release is on each release channel (channels.json in the same repository) into
# channels.tsv, so a release can move from Experimental to Stable without a new package. Only version numbers
# are taken from it.
# 5.0: one at a time. The install and the background guard used to download at the same moment into the same
# temporary file, and each threw away the other's half-finished download, so videos showed as unavailable until
# the next try. Now a second copy just stops (the first one finishes the job), and temporary files are per copy.
# Also the dark intro videos (5.1: and Penguins' light one; 5.4: Beach's two and Anime's dark one; 5.4.5: 8-Bit's and Claymation's dark ones), and the TLA screensaver video (on macOS 26 and later, where it can be used).
# 6.0.5: Code's light intro video, and a new version of Anime's dark one. A new version of a video goes up under a
# name of its own (REMOTE), so older packages keep finding the one their list expects.

WV_DIR="/Library/Application Support/ca.schoolathome.welcomevideo"
SOURCE="https://raw.githubusercontent.com/ebuskell-source/Default-wallpaper/main/TLA-BootPaper/videos"
LOG_FILE="/Library/Logs/ca.schoolathome.welcomevideo.log"
typeset -A HASHES=(
  tla                     7cb60be851fbcdf6a60176a524c3dee051cca3da8295be3a49cda3927f51fa9b
  frutiger-aero           b01287343a0b89460dc9c4403fb10ffff79cb61c7b21b6cb03c067656c3895da
  liquid-glass            fd3e3510cad5bfcdd5557bf1050d05b2a2d3452c7ef83ca07bc2c68138cb391f
  microsoft               d49eea24251e2424af6bed3ca5c33dd4abd2e184ec22aea11f837361697e30e7
  rainy                   7ae3580eb8bb70a1a692d764bca77a5670ada051262e4b208831c277c32899a7
  code                    0e8eea44df385807898f8b732aeb804fdd3b14c1d9d169fceebbdb0993f36b02
  bricks                  0c19192e6e13ef23946055a4593c1abba2dde8cace81408918d5a063c2488afd
  blocks                  0ce92e5a85115c42e8cd02cc994914300cd50158e66776e5035e1103cacdb7a3
  space                   1c9f81b94905fde5dfc765ed09a59b371aef771d4b79a752258c306791ef8db5
  claymation              dc729567f37032a23aa71d139cb663d22b1e469cb4c66d18bf8021d4fba9f503
  anime                   b0fc2c29f5305fe57e3617073227a9a8137f18337d5429fa74611f61653bdcaa
  penguins                2f6f7adbeadbe959e72218b194c0de7ca43d5596a8f67a2c76bd0743ef7434eb
  solarpunk               725ec78d91c5935963345c60f5b703f36fe017ca40cd47d6501fa956f05d304e
  pixel                   f9704533e611afbdc1a32d26e8d42bb95b7222e02ea8ecf75c4779d9daf076d3
  ocean                   6def8de6af1e729d56d8fa8e224d85d7a7a36993c8e772ff33fa75048020e803
  frutiger-aero-v2        bbce9fec534928fbae3dbe94e9f5a368f92aba439454ce8882df60fb8cf22460
  liquid-glass-original   5dae894482e3cd513baf6214da8a340f9da38ccb7f7589507c39b71bb26afbdf
  microsoft-original      b781ce6a57156694d5ec85a6dfc6e2521785a7afefcbda2e10a5b985277eb4f8
  fall                    9b2828fd96159967445718a8621265781397989135b8021bfeb6c18640fd9767
  christmas               6f22a687f31f120627804a3db693c0d6b4d7c588b66fdc3c730a1165a29718eb
  easter                  e68f1b26c63672fcece100904d81c5ad83250d449d45059bc361ac7101482f98
  sky-city                7d511086c4eaf32fa392034cbe7a981a2896d2796bcad76ee246f00cd72211fc
  blocks-dark             c9c6978de5739f27592f385f893102dfa66563fffd2cb66b6015439f3b7c8ce3
  frutiger-aero-dark      1d1e6210213e3beed4b0d07f7fa2da010d62a235b805051e18d0c5469b9dc255
  microsoft-dark          f30e43321a61681f3c6749a472fb96be521f99405d5dab56b1aa90003bb43ba8
  liquid-glass-dark       ce453b6435d599156b8316565ee45d8dde4e98358cbecf41569b686b5d98cf65
  bricks-dark             74a54c362c24bca8240f6f323df908d79488637ea96a7b9e551b142efdc60f37
  penguins-light          2efbec474c16367fabd03797e101d30a87fa92d4ee5ec6a3803433add727685b
  beach                   b5dc48a3c56440d755068a77f6744497f28e85d62e59be51fee6f4fa75412636
  beach-dark              431a1396dc5aecd4b1dd0c58e97b2e95adde9658c2f518ef763d5083ed60731f
  grumpy-cat              588c9cd54ba08bf1310c02f016967a9485bb240b6375b8844ef8793c92611f0f
  grumpy-cat-dark         4873ba4d689c05140d42c5f639ae137f11b4a3136fb1575a932885e50fc13109
  bonjovi                 7013cca50dbb60d823e9b38f43dfe00265d4629ade874766d8505495e08650c5
  bonjovi-dark            d9e9b6c11379d31d345e50ab0435b9ef08628b6ab40ad2f11b2e9fc63755c7d0
  anime-dark              8a2d221a6639fd6be1000694640647d627b93b89b81d6aaac2c218069a1f780d
  pixel-dark              b0cfb3db78ba60371f7ee92502bbb6fabc6709ff38d5b6bf562f38f59f0896ce
  claymation-dark         0970de40e5ff566bc0b354da8200709ae00ce3bf6b8d23dd3072eb3b675cb3bf
  solarpunk-dark          4c47774ee0d5957e18b69e1c227b7428ca51842943e813085eb11c29d06b5f95
  sky-city-dark           ad33f57f0ecf7d13dde0366661ca143f8e0f4beb6a53cb707fe81e5ac6705eb3
  space-light             42b2a456b88441ebed1bb1e53b88a4944b50b600baea23ff445ee696a9fa86d8
  ocean-dark              04e023547a1f6ed95097235ea95158a5e803bef505b5829c1f25cbcd4873a7e7
  code-light              e13a4b3c8067f69fe20b15f5178a4a43543c25e37673c0e99e18b9c9eb7eda3b
  winter                  9e0c57a315e3bc134ee74088083900eebe45917887ac2c7769542e7cd2f8658b
  winter-dark             c0d80835338478e3179cfe2b74ef42294f13edcb7cec90e0d708a7a4b8d9e291
)
# The file name in the repository, where it isn't <id>.mp4 (6.0.5).
typeset -A REMOTE=(anime-dark anime-dark-v2 pixel pixel-v2)   # (6.4.5: 8-Bit's new video)
# The TLA screensaver (5.0), played by Aerial: Screensaver/<SCREENSAVER_NAME>.
SCREENSAVER_FILE="tla-screensaver-2026.mov"
SCREENSAVER_NAME="TLA 2026 Screensaver.mov"
SCREENSAVER_SHA="4338e8bcec5f626eb9ca27a05545fab424e528051ad3fc86b706da69597a153c"
CHANNELS="https://raw.githubusercontent.com/ebuskell-source/Default-wallpaper/main/TLA-BootPaper/channels.json"
log() { print -r -- "$(/bin/date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG_FILE"; }
sha() { /usr/bin/shasum -a 256 "$1" 2>/dev/null | /usr/bin/awk '{ print $1 }' }

# One at a time (5.0): if another copy is already downloading, leave it to that one.
zmodload zsh/system 2>/dev/null
/bin/mkdir -p "$WV_DIR"
: >> "$WV_DIR/.sync.lock" 2>/dev/null
if ! zsystem flock -t 0 -f lockfd "$WV_DIR/.sync.lock" 2>/dev/null; then
  exit 75
fi

# Release channels (4.3)
json="$(/usr/bin/curl -fsSL --connect-timeout 10 --max-time 30 "$CHANNELS" 2>/dev/null)"
if [[ -n "$json" ]]; then
  stable="$(print -r -- "$json" | "/Library/Application Support/ca.schoolathome.welcomevideo/pl" stable - 2>/dev/null)"
  experimental="$(print -r -- "$json" | "/Library/Application Support/ca.schoolathome.welcomevideo/pl" experimental - 2>/dev/null)"
  re='^[0-9]{1,4}(\.[0-9]{1,4}){0,3}$'
  if [[ "$stable" =~ $re && "$experimental" =~ $re ]]; then
    line="stable	$stable"$'\n'"experimental	$experimental"
    if [[ "$(/bin/cat "$WV_DIR/channels.tsv" 2>/dev/null)" != "$line" ]]; then
      print -r -- "$line" > "$WV_DIR/.channels.$$.tmp" && /bin/chmod 644 "$WV_DIR/.channels.$$.tmp" &&
        /bin/mv -f "$WV_DIR/.channels.$$.tmp" "$WV_DIR/channels.tsv" && log "Release channels: stable $stable, experimental $experimental."
      /bin/rm -f "$WV_DIR/.channels.$$.tmp"
    fi
  else
    log "channels.json doesn't look right; keeping the release channels as they were."
  fi
fi

# get <url> <target> <sha256> <name for the log>: downloads to a temporary file of this copy's own, and keeps it
# only if it matches.
missing=0
get() {
  local temp="${2:h}/.${2:t}.$$.download"
  if /usr/bin/curl -fsSL --connect-timeout 10 --max-time 300 "$1" -o "$temp" 2>/dev/null \
     && [[ "$(sha "$temp")" == "$3" ]]; then
    /bin/chmod 644 "$temp" && /bin/mv -f "$temp" "$2" && log "Downloaded the $4."
  else
    missing=1; log "Couldn't get the $4 yet (offline, not uploaded yet, or the file doesn't match)."
  fi
  /bin/rm -f "$temp"
}

/bin/mkdir -p "$WV_DIR/Videos"
/bin/rm -f "$WV_DIR"/Videos/.*.download(N)   # (left over from before 5.0, or a copy that was stopped)
for id in ${(k)HASHES}; do
  target="$WV_DIR/Videos/$id.mp4"
  [[ -f "$target" && "$(sha "$target")" == "${HASHES[$id]}" ]] && continue
  get "$SOURCE/${REMOTE[$id]:-$id}.mp4" "$target" "${HASHES[$id]}" "$id video"
done
# A video taken off the list (3.3.8: Solarpunk, being redone) is removed, so nobody keeps playing it.
for f in "$WV_DIR"/Videos/*.mp4(N); do
  id="${f:t:r}"
  (( ${+HASHES[$id]} )) || { /bin/rm -f "$f" && log "Removed the $id video (no longer offered)."; }
done

# The screensaver video (5.0): only where Aerial can play it (macOS 26 and later).
major="$(/usr/bin/sw_vers -productVersion 2>/dev/null)"; major="${major%%.*}"
if [[ "$major" == <-> ]] && (( major >= 26 )); then
  /bin/mkdir -p "$WV_DIR/Screensaver"
  target="$WV_DIR/Screensaver/$SCREENSAVER_NAME"
  if [[ ! -f "$target" || "$(sha "$target")" != "$SCREENSAVER_SHA" ]]; then
    get "$SOURCE/$SCREENSAVER_FILE" "$target" "$SCREENSAVER_SHA" "screensaver video"
  fi
fi

(( missing )) || /usr/bin/touch "$WV_DIR/.videos-ok"
exit $missing
