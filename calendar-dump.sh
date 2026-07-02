#!/usr/bin/env bash
# calendar-dump.sh — refresh the brain right-rail's calendar + linear tickets.
# Runs on the Mac (headless claude here has the Google Calendar + Linear MCPs, same
# as the briefing). Dumps the next 3 days to calendar.json and my in-progress Linear
# issues to linear.json, then rsyncs both to Benito so brain.…ts.net shows a live
# schedule. Validates JSON before publishing.
TASK_NAME="calendar-dump"
source "$(dirname "$0")/common.sh"

WEB="$HOME/daily/.corpus/web"
OUT="$WEB/calendar.json"
LOUT="$WEB/linear.json"
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

# my in-progress Linear tickets → linear.json (rendered under the calendar in the rail)
read -r -d '' LPROMPT <<EOF || true
Use the Linear tool (mcp__claude_ai_Linear__list_issues) to list issues assigned to me
whose workflow state type is "started" (i.e. In Progress / In Review — actively being
worked, not todo/backlog/done). Then use the Write tool to write ONLY this JSON to the
file ${LOUT} (no prose, no markdown fence):
{"generated":"<ISO8601 now>","issues":[
  {"id":"<identifier e.g. ENG-123>","title":"...","state":"<state name>",
   "project":<project name or null>,"url":"<issue url>"}]}
issues sorted by most recently updated first. If there are none, write {"generated":"<ISO8601 now>","issues":[]}.
EOF

run_claude "$LPROMPT"

if python3 -c "import json; json.load(open('$LOUT'))" 2>/dev/null; then
    if rsync -az "$LOUT" benito@benitos-mac-mini:/srv/benbybenjacobs.com/brain/linear.json 2>>"$LOG_FILE"; then
        log "INFO" "linear published ($(python3 -c "import json;print(len(json.load(open('$LOUT'))['issues']))" 2>/dev/null) issues)"
    else
        log "WARN" "linear rsync to Benito failed"
    fi
else
    log "WARN" "linear.json missing/invalid — kept previous"
fi
log "INFO" "=== done ==="
