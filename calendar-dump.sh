#!/usr/bin/env bash
# calendar-dump.sh — refresh the brain right-rail's calendar.
# Runs on the Mac (headless claude here has the Google Calendar MCP, same as the
# briefing). Dumps the next 3 days to calendar.json and rsyncs it to Benito so
# brain.…ts.net shows a live schedule. Validates JSON before publishing.
TASK_NAME="calendar-dump"
source "$(dirname "$0")/common.sh"

WEB="$HOME/Documents/daily/.corpus/web"
OUT="$WEB/calendar.json"
mkdir -p "$WEB"

log "INFO" "=== calendar-dump ==="
if ! wait_for_network; then log "ERROR" "no network"; exit 1; fi

read -r -d '' PROMPT <<EOF || true
Use the Google Calendar tool (mcp__claude_ai_Google_Calendar__list_events) to list my events
for the next 3 days starting today, timeZone America/Chicago, orderBy startTime, pageSize 50.
Then use the Write tool to write ONLY this JSON to the file ${OUT} (no prose, no markdown fence):
{"generated":"<ISO8601 now>","tz":"America/Chicago","events":[
  {"date":"YYYY-MM-DD","start":"HH:MM","end":"HH:MM","title":"...",
   "video":<true if the event has a zoom/meet/slack-huddle link>,"loc":<location string or null>,
   "url":"<the event htmlLink>"}]}
All times 24-hour America/Chicago. Skip events I have declined. events sorted by date then start.
EOF

run_claude "$PROMPT"

if python3 -c "import json; json.load(open('$OUT'))" 2>/dev/null; then
    # cross-link each event to a same-date granola note (shared matcher; see granola-match.py)
    python3 "$(dirname "$0")/granola-match.py" "$OUT" >>"$LOG_FILE" 2>&1 || true
    if rsync -az "$OUT" benito@benitos-mac-mini:/srv/benbybenjacobs.com/brain/calendar.json 2>>"$LOG_FILE"; then
        log "INFO" "calendar published ($(python3 -c "import json;print(len(json.load(open('$OUT'))['events']))" 2>/dev/null) events)"
    else
        log "WARN" "rsync to Benito failed"
    fi
else
    log "WARN" "calendar.json missing/invalid — kept previous"
fi
log "INFO" "=== done ==="
