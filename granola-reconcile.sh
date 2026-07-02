#!/usr/bin/env bash
# granola-reconcile.sh — Pull + crosslink granola notes (every 15 min)
# Two fast checks, no Claude unless one trips:
#   1. local orphans — granola/*.md files not yet crosslinked from their daily note
#   2. pending meetings — today's calendar events that ENDED 10–90 min ago with no
#      matching local granola note yet (the note lives only in Granola's cloud until
#      a Claude pass pulls it via MCP; this is what used to wait for the noon tidy)
TASK_NAME="granola-reconcile"
MAX_RETRIES=1
source "$(dirname "$0")/common.sh"

log "INFO" "=== Starting granola-reconcile ==="
acquire_lock

need_claude=""

# Check 1: local orphans (bash only)
reconcile_output=$("$DAILY_DIR/granola/reconcile" 2>&1) || true
if ! echo "$reconcile_output" | grep -q "All granola notes are crosslinked"; then
    orphan_count=$(echo "$reconcile_output" | grep -oE '^[0-9]+' | head -1)
    log "INFO" "Found ${orphan_count:-some} orphaned granola note(s)"
    need_claude="orphans"
fi

# Check 2: recently-ended meetings with no granola note pulled yet. calendar.json is
# refreshed every 30 min by calendar-dump and re-matched every 10 min by granola-relink,
# and its per-event "granola" key is set iff a matching local note exists. The 10–90 min
# window bounds retries for meetings that will never have notes (~5 attempts max).
pending=$(python3 - <<'PYEOF'
import json, datetime, os, sys
p = os.path.expanduser("~/daily/.corpus/web/calendar.json")
try:
    cal = json.load(open(p))
except Exception:
    sys.exit(0)
now = datetime.datetime.now()
today = now.strftime("%Y-%m-%d")
for e in cal.get("events", []):
    if e.get("date") != today or e.get("granola"):
        continue
    if e.get("start") == "00:00":          # all-day / placeholder blocks
        continue
    end = e.get("end") or e.get("start")
    try:
        h, m = map(int, end.split(":"))
    except Exception:
        continue
    mins = (now - now.replace(hour=h, minute=m, second=0, microsecond=0)).total_seconds() / 60
    if 10 <= mins <= 90:
        print(e.get("title", "untitled"))
PYEOF
) || true
if [[ -n "$pending" ]]; then
    log "INFO" "Meeting(s) ended without a granola note yet: $(echo "$pending" | tr '\n' ';')"
    need_claude="${need_claude:+$need_claude+}pending-meetings"
fi

if [[ -z "$need_claude" ]]; then
    log "INFO" "Nothing to pull or link, skipping Claude"
    log "INFO" "=== Finished (nothing to do) ==="
    exit 0
fi

if ! wait_for_network; then
    log "ERROR" "Aborting: no network"
    exit 1
fi

log "INFO" "Invoking Claude (/daily tidy) — reason: $need_claude"
run_claude "/daily tidy"
exit_code=$?

log "INFO" "=== Finished (exit $exit_code) ==="
exit "$exit_code"
