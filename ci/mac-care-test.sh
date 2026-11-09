# 7.6.0: the macOS updates row, as it is and with no room (need forced up), with a 300 MB file in Downloads.
mkdir -p out; mkfile -n 300m "$HOME/Downloads/Big test video.mov"
sed 's/local -i need=3;/local -i need=99999;/' ci/macsrc/common.zsh > /tmp/common-noroom.zsh
zsh -c 'source ci/macsrc/common.zsh 2>/dev/null; wv_care_checks' > out/rows.txt 2>&1
zsh -c 'source /tmp/common-noroom.zsh 2>/dev/null; wv_care_checks' > out/rows-noroom.txt 2>&1
defaults read /Library/Preferences/com.apple.SoftwareUpdate RecommendedUpdates > out/recommended.txt 2>&1
grep osupdate out/rows.txt out/rows-noroom.txt > out/summary.txt
