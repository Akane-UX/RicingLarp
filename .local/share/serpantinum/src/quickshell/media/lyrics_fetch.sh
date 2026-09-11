#!/usr/bin/env bash
# lyrics_fetch.sh — Fetch synced lyrics from lrclib.net
# Args: $1=artist, $2=title, $3=position_seconds
# Output: JSON { lrc: [...{t,text}], error: string|null }
#
# Uses same cache dir pattern as art_fetch.sh

ARTIST="$1"
TITLE="$2"
POSITION="${3:-0}"

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/lirik"
mkdir -p "$CACHE_DIR"

# ── Cache key ──────────────────────────────────────────────────────────────────
SAFE_NAME="${ARTIST} - ${TITLE}"
CACHE_KEY=$(echo -n "$SAFE_NAME" | md5sum | cut -d' ' -f1)
CACHE_FILE="$CACHE_DIR/${CACHE_KEY}.lrc.json"

# ── Return cached if available ─────────────────────────────────────────────────
if [ -f "$CACHE_FILE" ]; then
    cat "$CACHE_FILE"
    exit 0
fi

# ── Helper: build JSON LRC array from raw LRC text ────────────────────────────
parse_lrc() {
    local lrc_raw="$1"
    echo "$lrc_raw" | python3 -c "
import sys, json, re

lines = sys.stdin.read().splitlines()
result = []
for line in lines:
    m = re.match(r'\[(\d+):(\d+\.\d+|\d+)\](.*)', line)
    if m:
        mins = int(m.group(1))
        secs = float(m.group(2))
        text = m.group(3).strip()
        t = mins * 60 + secs
        result.append({'t': t, 'text': text})
result.sort(key=lambda x: x['t'])
print(json.dumps(result))
"
}

# ── Fetch from lrclib.net ──────────────────────────────────────────────────────
fetch_from_api() {
    local artist_enc title_enc

    artist_enc=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$ARTIST" 2>/dev/null)
    title_enc=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$TITLE" 2>/dev/null)

    # Try exact match first
    local url="https://lrclib.net/api/get?artist_name=${artist_enc}&track_name=${title_enc}"
    local response
    response=$(curl -s -L --max-time 10 \
        -H "User-Agent: Serpentinum-LyricWidget/1.0 (https://github.com/)" \
        "$url" 2>/dev/null)

    local synced
    synced=$(echo "$response" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    s = d.get('syncedLyrics') or ''
    print(s if s else '')
except:
    print('')
" 2>/dev/null)

    if [ -n "$synced" ]; then
        echo "$synced"
        return 0
    fi

    # Fallback: search endpoint
    local q_enc
    q_enc=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "${ARTIST} ${TITLE}" 2>/dev/null)
    local search_url="https://lrclib.net/api/search?q=${q_enc}"
    local search_resp
    search_resp=$(curl -s -L --max-time 10 \
        -H "User-Agent: Serpentinum-LyricWidget/1.0 (https://github.com/)" \
        "$search_url" 2>/dev/null)

    synced=$(echo "$search_resp" | python3 -c "
import sys, json
try:
    items = json.load(sys.stdin)
    if isinstance(items, list):
        for item in items:
            s = item.get('syncedLyrics') or ''
            if s:
                print(s)
                break
except:
    pass
" 2>/dev/null)

    if [ -n "$synced" ]; then
        echo "$synced"
        return 0
    fi

    return 1
}

# ── Main ───────────────────────────────────────────────────────────────────────
if [ -z "$ARTIST" ] && [ -z "$TITLE" ]; then
    echo '{"lrc":[],"error":"no_track"}'
    exit 0
fi

raw_lrc=$(fetch_from_api)
if [ $? -ne 0 ] || [ -z "$raw_lrc" ]; then
    echo '{"lrc":[],"error":"not_found"}'
    exit 0
fi

lrc_json=$(parse_lrc "$raw_lrc")
result=$(python3 -c "import json,sys; print(json.dumps({'lrc': json.loads(sys.argv[1]), 'error': None}))" "$lrc_json" 2>/dev/null)

if [ -z "$result" ]; then
    echo '{"lrc":[],"error":"parse_error"}'
    exit 0
fi

# Cache the result
echo "$result" > "$CACHE_FILE"
echo "$result"
