#!/usr/bin/env bash
# granola-relink.sh — cheap, frequent re-link of calendar events to granola notes.
# No Claude / Google query: just re-runs the title↔granola matcher on the existing
# calendar.json and republishes, so granola links appear within ~10 min of a note
# syncing (the full calendar-dump that re-queries Google runs every 30 min).
TASK_NAME="granola-relink"
source "$(dirname "$0")/common.sh"

OUT="$HOME/Documents/daily/.corpus/web/calendar.json"
[ -f "$OUT" ] || exit 0

result=$(python3 "$(dirname "$0")/granola-match.py" "$OUT" 2>>"$LOG_FILE")
if [ "$result" = "changed" ]; then
    if rsync -az "$OUT" benito@benitos-mac-mini:/srv/benbybenjacobs.com/brain/calendar.json 2>>"$LOG_FILE"; then
        log "INFO" "granola links changed → calendar republished"
    else
        log "WARN" "rsync to Benito failed"
    fi
fi
