#!/bin/bash
export HYPRLAND_INSTANCE_SIGNATURE=$(ls /run/user/1000/hypr/ 2>/dev/null | head -1)

ACTIVE=$(hyprctl activeworkspace -j 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null || echo "1")
mkdir -p /tmp/serpantinum_ws_preview

# Capture active workspace dulu
grim -o eDP-1 -s 0.25 /tmp/serpantinum_ws_preview/${ACTIVE}.png >/dev/null 2>&1

# Workspace yang punya isi (ada windownya)
OCCUPIED=$(hyprctl workspaces -j 2>/dev/null | python3 -c "
import sys, json
try:
    ws = json.load(sys.stdin)
    for w in ws:
        wid = w.get('id', 0)
        wins = w.get('windows', 0)
        if wins > 0:
            print(wid)
except:
    pass
" 2>/dev/null)

for wsid in $OCCUPIED; do
    [ "$wsid" = "$ACTIVE" ] && continue
    hyprctl dispatch workspace "$wsid" >/dev/null 2>&1
    sleep 0.18
    grim -o eDP-1 -s 0.25 /tmp/serpantinum_ws_preview/${wsid}.png >/dev/null 2>&1
done

# Balik ke workspace asal
hyprctl dispatch workspace "$ACTIVE" >/dev/null 2>&1
