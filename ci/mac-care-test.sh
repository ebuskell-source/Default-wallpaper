# 7.6.0: TLA Care's own macOS update check (guard's wv_os_check), then the row, as is and with no room.
set -x; mkdir -p out; export WV_DIR="$PWD/wvdir"; mkdir -p "$WV_DIR/Care"; mkfile -n 300m "$HOME/Downloads/Big test video.mov"
# wv_os_check, taken from guard.zsh, run and waited for
awk '/^wv_os_check\(\) \{/,/^}/' ci/macsrc/guard.zsh > /tmp/oscheck.zsh
start=$(date +%s); zsh -c "source /tmp/oscheck.zsh; wv_os_check"
for i in $(seq 1 60); do [ -e "$WV_DIR/Care/.osupdate.running" ] || break; sleep 5; done
echo "check took $(( $(date +%s) - start ))s" > out/summary.txt; cat "$WV_DIR/Care/osupdate" >> out/summary.txt
sed -e 's/local -i need=\$(( (2 \* kib + 1048575) \/ 1048576 + 2 ))/local -i need=99999/' -e 's/(( need < 15 )) \&\& need=15/true/' ci/macsrc/common.zsh > /tmp/common-noroom.zsh
zsh -c 'source ci/macsrc/common.zsh 2>/dev/null; wv_care_checks' 2>&1 | grep osupdate >> out/summary.txt
zsh -c 'source /tmp/common-noroom.zsh 2>/dev/null; wv_care_checks' 2>&1 | grep osupdate >> out/summary.txt
