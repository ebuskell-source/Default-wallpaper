#!/bin/bash
# Plays each theme's intro video with tla-player and its greeting style, taking screenshots along the way.
set -u
mkdir -p out
chmod +x ci/tla-player; xattr -cr ci/tla-player 2>/dev/null
BASE=https://raw.githubusercontent.com/ebuskell-source/Default-wallpaper/main/TLA-BootPaper/videos
ONLY="${ONLY:-}"
run_one() {   # run_one <id> <spec> <tag> [arch]
  local id="$1" spec="$2" tag="$3" arch="${4:-}"
  [[ -f "v-$id.mp4" ]] || curl -sfL -o "v-$id.mp4" "$BASE/$id.mp4"
  local start; start=$(python3 -c 'import time;print(time.time())')
  if [[ -n "$arch" ]]; then
    TLA_PLAYER_TIMING=1 arch -$arch ./ci/tla-player "v-$id.mp4" 1 6.5 "Good afternoon, Sevilen!" "$spec" > "out/$tag.result" 2> "out/$tag.timing" &
  else
    TLA_PLAYER_TIMING=1 ./ci/tla-player "v-$id.mp4" 1 6.5 "Good afternoon, Sevilen!" "$spec" > "out/$tag.result" 2> "out/$tag.timing" &
  fi
  local pid=$!
  for t in 0.8 1.2 1.7 2.4 3.4 5.3; do
    python3 -c "import time,sys; d=$start+$t-time.time(); time.sleep(d if d>0 else 0)"
    screencapture -x -t jpg "out/$tag-$t.jpg"
  done
  wait $pid
  echo "$tag: $(cat out/$tag.result) | $(tr '\n' ' ' < out/$tag.timing)" >> out/summary.txt
}
while IFS=$'\t' read -r id spec; do
  [[ -n "$ONLY" && " $ONLY " != *" $id "* ]] && continue
  run_one "$id" "$spec" "$id"
done < ci/greeting-styles.tsv
# Intel build (through Rosetta) and no greeting at all
spec=$(awk -F'\t' '$1=="blocks"{print $2}' ci/greeting-styles.tsv)
run_one blocks "$spec" blocks-x86 x86_64
TLA_PLAYER_TIMING=1 ./ci/tla-player v-tla.mp4 0 3 > out/nogreet.result 2> out/nogreet.timing; echo "nogreet: $(cat out/nogreet.result)" >> out/summary.txt
./ci/tla-player /nonexistent.mp4 1 5 >> out/summary.txt
sw_vers >> out/summary.txt
