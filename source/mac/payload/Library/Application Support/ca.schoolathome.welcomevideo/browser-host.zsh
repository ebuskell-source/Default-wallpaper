#!/bin/zsh
# browser-host.zsh (6.3.5) - tells the TLA New Tab extension (Chrome and Edge) which background is on this person's
# desktop, so the TLA new tab page shows the same one. Started by the browser (native messaging; the manifests in
# /Library/Google/Chrome/NativeMessagingHosts and /Library/Microsoft/Edge/NativeMessagingHosts allow only that
# extension), as the person. Answers {"id": "<background>", "look": "light|dark"}, and nothing else.
WV_DIR="/Library/Application Support/ca.schoolathome.welcomevideo"
source "$WV_DIR/common.zsh" >/dev/null 2>&1
id=""
if wv_signed_out 2>/dev/null; then id=tla      # (TLA Classic until they sign in)
else id="$(wv_current_background 2>/dev/null)"; fi
[[ "$id" =~ '^[a-z0-9-]{1,40}$' ]] || id=""
look="$(wv_mode 2>/dev/null)"; [[ "$look" == (light|dark) ]] || look=""
json="{\"id\":\"$id\",\"look\":\"$look\"}"
n=${#json}
# (native messaging: the length, as 4 bytes, lowest first, then the JSON)
printf "\\$(printf %03o $(( n & 255 )))\\$(printf %03o $(( (n >> 8) & 255 )))\\000\\000%s" "$json"
