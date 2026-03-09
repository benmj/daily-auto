#!/usr/bin/env bash
# daily-note.sh — Create today's daily note (07:30 daily)
TASK_NAME="daily-note"
source "$(dirname "$0")/common.sh"

log "INFO" "=== Starting daily-note ==="
acquire_lock

if ! wait_for_network; then
    log "ERROR" "Aborting: no network"
    exit 1
fi

run_claude "/daily"
exit_code=$?

log "INFO" "=== Finished (exit $exit_code) ==="
exit "$exit_code"
